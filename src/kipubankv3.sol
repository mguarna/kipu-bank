//SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/*///////////////////////
        Imports
///////////////////////*/
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/*  Representación del contrato Router de Uniswap V2, que permite a este
contrato llamar a sus funciones externas */
interface IUniswapV2Router02 {
    // Devuelve la dirección del token WETH (Wrapped Ether), esencial para manejar swaps que involucran a ETH
    function WETH() external pure returns (address);

    /* Ejecuta un swap donde conoces la cantidad exacta de token de entrada (amountIn) y especificas la cantidad mínima a recibir (amountOutMin)*/
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    /* Ejecuta un swap donde la entrada es Ether nativo (usando payable) y se especifica la cantidad mínima a recibir (amountOutMin) */
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    /* Simula internamente qué cantidad de tokens se recibirían según el estado actual del pool */
    function getAmountsOut(uint amountIn, address[] calldata path)
        external
        view
        returns (uint[] memory amounts);
}

/**
	*@title KipuBankV3
	*@notice contrato correspondiente al entregable final del Modulo4
    *@notice OBJETIVOS
    *        - 1. Manejar cualquier token intercambiable en Uniswap V2
    *        - 2. Ejecutar swaps de tokens dentro del smart contract.
    *        - 3. Preservar la funcionalidad de KipuBankV2.
    *        - 4. Respetar el límite del banco.
    *        - 5. Alcanzar un 50% de cobertura de pruebas
	*@author mguarna
	*@custom:security Contrato con fines educativos. No usar en producción.
*/
contract KipuBankV3 is Ownable, ReentrancyGuard {
    /*///////////////////////
        Declaracion de tipos
    ///////////////////////*/
    using SafeERC20 for IERC20;

    // Dirección del Router de Uniswap V2
    IUniswapV2Router02 public immutable ROUTER;

	/*///////////////////////
					Variables
	///////////////////////*/

    ///@notice USDC Address in Sepolia
    address private immutable usdc;

    ///@notice WETH Address in Sepolia
    address private immutable weth;

	///@notice variable inmutable para establecer limite de retiro de fondos en USD
	uint256 private immutable _withdrawMaxAllowed;

    ///@notice variable para establecer limite global de depositos en USD
    uint256 private _bankCap;

    ///@notice variable para controlar el estado actual de los depositos en USD
    uint256 private _bankCapStatus;

    ///@notice variable para llevar el control del numero total de depositos en kipuBank
    uint256 private _totalDepositsKipuBank;

    ///@notice variable para llevar el control del numero total de extracciones
    uint256 private _totalWithdrawsKipuBank;

    //@notice variable para almacenar los movimientos del usuario
    struct AccountState {
        uint256 amount;
        uint256 totalDeposits;
        uint256 totalWithdraws;
        uint256 maxStored;
    }

	///@notice mapping para almacenar cuentas de usuario y sus movimientos en diferentes tokens
    mapping(address => mapping(address userAccount => AccountState)) vault;

	/*///////////////////////
						Events
	////////////////////////*/
    ///@notice evento emitido cuando el deposito fue exitoso
	event DepositSuccessful(address wallet, string msg);

    ///@notice evento emitido cuando la extraccion fue exitosa
    event TransferSuccessful(address wallet, string msg);

    ///@notice evento emitido cuando un tercero transfirio de manera exitosa un monto delimitado
    event TokenTransfer(address from, address to, uint256 value);

    ///@notice evento emitido cuando se habilita a un tercero a transferir un monto delimitado
    event TokenApproval(address owner, address spender, uint256 value);

    ///@notice evento emitido cuando el owner modifica la capacidad de KipuBank
    event BankCapacityUpdated(uint256 _bankCap);

    ///@notice evento que se emite después de cada swap exitoso
    event SwapExecuted(uint amountIn, uint amountOut);

	/*///////////////////////
						Errors
	///////////////////////*/
    ///@notice error emitido cuando falla el intento de deposito de tokens por falta de capacidad de KipuBank
    error KipuBankWithoutCapacity(string errMessage);

    ///@notice error emitido cuando falla el intento de extraccion de USDC
	error WithdrawFailed(uint256 maxAllowed, uint256 balance, uint256 amount);

    ///@notice error emitido cuando falla la transferencia
    error TransferFailed(bytes err);

    ///@notice error emitido cuando se intenta interactuar con el contrato mediante un llamado invalido
    error InvalidReceiveCall(string errMessage);

    ///@notice error emitido cuando se intenta interactuar con el contrato mediante un llamado invalido
    error InvalidCallData(bytes receivedData);

    ///@notice error emitido bankCap no puede ser actualizado
    error BankCapacityUpdateFailed(uint256 newBankCap, uint256 currentStatus);

	/*///////////////////////
					Functions
	///////////////////////*/

	constructor(uint256 withdrawMaxAllowed
        , uint256 bankCap
        , address owner
        , address router
        , address usdc_addr
    ) Ownable(owner)
    {
		_withdrawMaxAllowed = withdrawMaxAllowed;
        _bankCap = bankCap;

        require(router != address(0), "router-zero");
        ROUTER = IUniswapV2Router02(router);

        weth = ROUTER.WETH();

        usdc = address(usdc_addr);
	}

    /*///////////////////////
        Public functions
    ///////////////////////*/

    /**
        *@notice Función que muestra el saldo tokens de una wallet en especifico
        *@param _wallet la direccion de la billetera a consultar saldo
        *@return El saldo de USD
    */
    function balanceOf(address _wallet) public view returns (uint256)
    {
        return vault[usdc][_wallet].amount;
    }

    /*///////////////////////
        External functions
    ///////////////////////*/

    ///@notice función fallback no permitida para recibir ETH. Rechaza el deposito.
	receive() external payable
    {
        revert InvalidReceiveCall("It's not possible to transfer ETH this way");
    }

    ///@notice función fallback no permitida para recibir ETH. Rechaza el deposito.
	fallback() external payable
    {
        revert InvalidCallData(msg.data);
    }

	/**
		*@notice función para recibir ETH y swapear a USD
		*@notice esta función emite un evento para informar el correcto swap a USD
	*/
	function DepositEth() external payable nonReentrant
    {
        require(msg.value > 0, "zero-eth");

        // path: WETH -> USDC
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = usdc;

        uint[] memory amountsOut = ROUTER.getAmountsOut(msg.value, path);
        uint256 amountInUsd = amountsOut[1];

        // Chequear estado de KipuBank
        bool bankStatus = _HasCapacityKipuBank(amountInUsd);
        if (!bankStatus)
        {
            revert KipuBankWithoutCapacity("KipuBank has no capacity to store more USD");
        }

        vault[usdc][msg.sender].totalDeposits++;
        vault[usdc][msg.sender].maxStored += amountInUsd;
		vault[usdc][msg.sender].amount += amountInUsd;

        // Actualizar totalDeposits para trackeo interno
        _totalDepositsKipuBank++;

        // Update total balance (USD)
        _bankCapStatus += amountInUsd;

        uint256 finalAmountInUsd;

        // Ejecutar el swap con slippage del 1%
        uint256 amountOutEstimated = (amountsOut[1] * 99 / 100);
        finalAmountInUsd = swapExactEthForUSD(amountOutEstimated);

        // Actualizar billetera y emitir evento
		emit DepositSuccessful(msg.sender, "Deposito realizado con exito");

        // Realizar ajustes finales
        if(finalAmountInUsd != amountInUsd)
        {
            if (finalAmountInUsd - amountInUsd > 0)
            {
                vault[usdc][msg.sender].maxStored += (finalAmountInUsd - amountInUsd);
                vault[usdc][msg.sender].amount += (finalAmountInUsd - amountInUsd);
                _bankCapStatus += (finalAmountInUsd - amountInUsd);
            }
            else
            {
                vault[usdc][msg.sender].maxStored -= (amountInUsd - finalAmountInUsd);
                vault[usdc][msg.sender].amount -= (amountInUsd - finalAmountInUsd);
                _bankCapStatus -= (amountInUsd - finalAmountInUsd);
            }
        }
	}

    /**
     * @notice función para recibir ERC20 y swapear a USD. En caso de recibir USDC omite el swap
	 * @notice esta función emite un evento para informar el correcto swap a USD
     * @param _amount la cantidad a ser depositada.
     * @param _erc20Addr the input ERC20 token address
    */
    function DepositErc20(uint256 _amount, address _erc20Addr) external nonReentrant
    {
        require(_amount > 0, "zero-erc20");

        IERC20 _iErc20 = IERC20(_erc20Addr);
        uint256 allowance_ = _iErc20.allowance(msg.sender, address(this));
        if (allowance_ < _amount)
        {
            revert("DepositErc20: allowance insufficient");
        }

        // Monto estimado en USD luego del swap
        uint256 amountInUsd = 0;

        // path: ERC20 -> USDC
        address[] memory path = new address[](2);
        path[0] = _erc20Addr;
        path[1] = usdc;

        bool isUsdcToken = _erc20Addr == usdc;

        // No hacer swap si el deposito es en USDC
        if (isUsdcToken)
        {
            amountInUsd = _amount;
        }
        else
        {
            uint[] memory amountsOut = ROUTER.getAmountsOut(_amount, path);
            amountInUsd = amountsOut[1];
        }

        // Chequear estado de KipuBank
        bool bankStatus = _HasCapacityKipuBank(amountInUsd);
        if (!bankStatus)
        {
            revert KipuBankWithoutCapacity("KipuBank has no capacity to store more USD");
        }

        vault[usdc][msg.sender].totalDeposits++;
        vault[usdc][msg.sender].maxStored += amountInUsd;
		vault[usdc][msg.sender].amount += amountInUsd;

        // Actualizar totalDeposits para trackeo interno
        _totalDepositsKipuBank++;

        // Update total balance (USD)
        _bankCapStatus += amountInUsd;

        // Balance previo al deposito
        uint256 balanceBefore = _iErc20.balanceOf(address(this));

        // Permitir que el contrato reciba tokens de la wallet
        _iErc20.safeTransferFrom(msg.sender, address(this), _amount);

        // Balance posterior al deposito
        uint256 balanceAfter = _iErc20.balanceOf(address(this));
        uint256 _amountReceived = balanceAfter - balanceBefore;

        // El contrato autoriza al router la extraccion de los tokens para el posterior swap
        _iErc20.safeIncreaseAllowance(address(ROUTER), _amountReceived);

        uint256 finalAmountInUsd;

        // Ejecutar el swap
        if (!isUsdcToken)
        {
            // Ejecutar el swap con slippage del 1%
            uint256 amountOutEstimated = (amountInUsd * 99 / 100);
            finalAmountInUsd = swapExactErc20ForUSD(_erc20Addr, _amountReceived, amountOutEstimated);
        }

        // Emitir evento
		emit DepositSuccessful(msg.sender, "Deposito realizado con exito");

        // Realizar ajustes de saldo finales en caso de haber realizado swap de tokens
        if(!isUsdcToken && finalAmountInUsd != amountInUsd)
        {
            if (finalAmountInUsd - amountInUsd > 0)
            {
                vault[usdc][msg.sender].maxStored += (finalAmountInUsd - amountInUsd);
                vault[usdc][msg.sender].amount += (finalAmountInUsd - amountInUsd);
                _bankCapStatus += (finalAmountInUsd - amountInUsd);
            }
            else
            {
                vault[usdc][msg.sender].maxStored -= (amountInUsd - finalAmountInUsd);
                vault[usdc][msg.sender].amount -= (amountInUsd - finalAmountInUsd);
                _bankCapStatus -= (amountInUsd - finalAmountInUsd);
            }
        }
    }

    /**
		*@notice función para retirar USDC protegida contra reentrancy
        *@param _amount es el monto a retirar
		*@dev esta función debe emitir un evento informando el correcto egreso de ETH.
	*/
    function Withdraw(uint256 _amount) external nonReentrant
    {
        // Chequear validez del monto a retirar
        bool isAllowed = _IsWithdrawAllowed(_amount);
        if(!isAllowed)
        {
            revert WithdrawFailed(_withdrawMaxAllowed, vault[usdc][msg.sender].amount, _amount);
        }

        // Actualizar saldo antes de enviar
        vault[usdc][msg.sender].amount -= _amount;

        // Proceder con el envio de USDC
        IERC20 _iErc20 = IERC20(usdc);
        _iErc20.safeTransfer(msg.sender, _amount);

        emit TransferSuccessful(msg.sender, "Retiro realizado con exito");

        // Actualizar variables de estado para trackeo interno
        _totalWithdrawsKipuBank++;
        _bankCapStatus -= _amount;
    }

    /**
     * @notice función para actualizar el monto maximo en USD que KipuBank puede almacenar en su totalidad
     * @param newBankCap es el nuevo monto maximo en USD tolerado por Kipubank
     * @dev debe ser llamada solo por el propietario
    */
    function setBankCapacity(uint256 newBankCap) external onlyOwner {

        if (_bankCapStatus > newBankCap)
        {
            revert BankCapacityUpdateFailed(newBankCap, _bankCapStatus);
        }

        _bankCap = newBankCap;
        emit BankCapacityUpdated(_bankCap);
    }

    /**
     * @notice función para ver el estado general de KipuBank
     * @dev debe ser llamada solo por el propietario
     * @return el saldo general y la cantidad total de depositos/extracciones realizados
     */
     function getKipuBankStatus() external view onlyOwner returns (uint256, uint256, uint256, uint256)
     {
        return (_bankCap, _bankCapStatus, _totalDepositsKipuBank, _totalWithdrawsKipuBank);
     }

    /*///////////////////////
        Internal functions
    ///////////////////////*/
    /**
     * @notice Swap ETH -> USDC using Uniswap V2
     * @param amountOutMin la minima cantidad USD que se espera recibir
     * @return The amount of USD swapped
     */
    function swapExactEthForUSD(uint256 amountOutMin) internal returns (uint256)
    {
        // path: WETH -> USDC
        address[] memory path = new address[](2);
        path[0] = weth;
        path[1] = usdc;

        /* The ETH is sent to the Router, converted to WETH, exchanged for tokenOut,
        and the final token is sent directly back*/
        uint[] memory amounts = ROUTER.swapExactETHForTokens{value: msg.value}(amountOutMin, path, address(this), 9999999999);

        emit SwapExecuted(msg.value, amounts[amounts.length - 1]);

        return amounts[amounts.length - 1];
    }

    /**
     * @notice Swap ERC20 -> USDC using Uniswap V2
     * @param addr ERC20 addr to be swaped
     * @param _amount la cantidad de tokens a cambiar
     * @param amountOutMin la minima cantidad USD que se espera recibir
     * @return The amount of USD swapped
     */
    function swapExactErc20ForUSD(address addr, uint256 _amount, uint256 amountOutMin) internal returns (uint256)
    {
        // path: ERC20 -> USDC
        address[] memory path = new address[](2);
        path[0] = addr;
        path[1] = usdc;

        // Execute swap
        uint[] memory amounts = ROUTER.swapExactTokensForTokens(_amount, amountOutMin, path, address(this), 9999999999);

        emit SwapExecuted(_amount, amounts[amounts.length - 1]);

        return amounts[amounts.length - 1];
    }

    /*///////////////////////
        Private functions
    ///////////////////////*/

    /**
        *@notice Función que chequea si kipuBank tiene capacidad de guardado o si se llego al limite
        *@param amount la cantidad de tokens en USD a depositar
        *@return true para informar que se puede realizar deposito
    */
    function _HasCapacityKipuBank(uint256 amount) private view returns(bool)
    {
        if(_bankCapStatus + amount > _bankCap)
        {
            return false;
        }
        return true;
    }

    /**
        *@notice Función que chequea si el monto de retirada solicitado esta permitido
        *@param amount la cantidad de tokens que se solicita retirar
        *@return true para informar que se puede realizar retiro
    */
    function _IsWithdrawAllowed(uint256 amount) private view returns(bool)
    {
        //1- Chequear limite de extraccion permitido
        //2- Chequear que el saldo disponible sea mayor a lo que desea retirar
        if(amount > _withdrawMaxAllowed ||
            amount > vault[usdc][msg.sender].amount)
        {
            return false;
        }

        return true;
    }
}
