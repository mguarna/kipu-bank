//SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/*///////////////////////
        Imports
///////////////////////*/
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ETHDevPackNFT} from "./ETHDevPackNFT.sol";

/*///////////////////////
        Libraries
///////////////////////*/
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/*///////////////////////
        Interfaces
///////////////////////*/
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

address constant ethAddr = address(0x0000000000000000000000000000000000000000);
address constant usdcAddr = address(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238);

/**
	*@title KipuBankV2
	*@notice contrato correspondiente al entregable final del Modulo3
	*@author mguarna
	*@custom:security Contrato con fines educativos. No usar en producción.
*/
contract KipuBankV2 is Ownable {
    /*///////////////////////
        Declaracion de tipos
    ///////////////////////*/
    using SafeERC20 for IERC20;

    /*///////////////////////
					Constantes
	///////////////////////*/

    ///@notice variable constante para almacenar el heartbeat del Data Feed
    uint16 constant ORACLE_HEARTBEAT = 3600;
    
    ///@notice variable constante para almacenar el factor de decimales
    uint256 constant DECIMAL_FACTOR = 1 * 10 ** 20;

    ///@notice variable constante para calcular tiempo minimo que debe permanecer depositada la cantidad de ETH
    ///@dev a fines de testeo se define en 2 minutos. En la realidad se esperaria sean al menos 3 meses
    uint256 constant TIME_LAPSED_TO_GRANT_NFT = 120;

    ///@notice variable constante para indicar la cantidad maxima de NFTs que KipuBank otorgara
    uint256 constant MAX_NFT = 4;

	/*///////////////////////
					Variables
	///////////////////////*/
	///@notice variable inmutable para establecer limite de retiro de fondos
	uint256 private immutable _withdrawMaxAllowedEth;
    
    ///@notice variable inmutable para establecer el monto minimo a depositar para abrir una cuenta
    uint256 private immutable _minDepositRequiredFirstTimeEth;

    ///@notice variable para establecer limite global de depositos
    uint256 private _bankCap;

    ///@notice variable para controlar el estado actual de los depositos
    uint256 private _bankCapStatus;

    ///@notice variables para llevar el control del numero total de depositos en kipuBank
    uint256 private _totalDepositsKipuBank;
    
    ///@notice variables para llevar el control del numero total de extracciones
    uint256 private _totalWithdrawsKipuBank;

    //@notice variable para trackear la cantidad de NFTs granteados por KipuBank desde su despliegue
    uint256 private _nftsGrantedByKipuBank;

    //@notice variable para blockear intentos de reentrancia
    bool private _reentrancyLock;

    //@notice variable para almacenar los movimientos del usuario
    struct AccountState {
        uint256 amount;
        uint256 totalDeposits;
        uint256 minBalance;
        bool rewardGranted;
        uint256 timestampFirstDeposit;
    }

	///@notice mapping para almacenar cuentas de usuario y sus movimientos tanto en ETH como en USDC
    mapping(address => mapping(address userAccount => AccountState)) vault;

    ///@notice variable inmutable para almacenar la dirección de USDC
    IERC20 immutable _iUsdc;
    
    ///@notice variable inmutable para almacenar el NFT de EDP
    ETHDevPackNFT immutable _iEdp;

    ///@notice variable para almacenar la dirección del Chainlink Feed
    ///@dev 0x694AA1769357215DE4FAC081bf1f309aDC325306 Ethereum ETH/USD
    AggregatorV3Interface public _feeds;

    enum Token {
        TOKEN_ETH,
        TOKEN_USDC
    }

    ///@notice variable para almacenar la dirección del Chainlink Feed
    string[MAX_NFT] private _images;

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

    ///@notice evento emitido se premia a wallet por su fidelidad
    event AccountRewarded(address owner, string msg);

    ///@notice evento emitido cuando el owner modifica la capacidad de KipuBank
    event BankCapacityUpdated(uint256 _bankCap);

	/*///////////////////////
						Errors
	///////////////////////*/
	///@notice error emitido cuando falla el intento de deposito de ETH
	error DepositFailedEth(uint256 permitted, uint256 amount, uint256 _minDepositRequiredFirstTime);

    ///@notice error emitido cuando falla el intento de deposito de USDC
	error DepositFailedUsdc(uint256 permitted, uint256 amount);
	
    ///@notice error emitido cuando falla el intento de extraccion de ETH
	error WithdrawFailedEth(uint256 maxAllowed, uint256 balance, uint256 amount);

    ///@notice error emitido cuando falla el intento de extraccion de USDC
	error WithdrawFailedUsdc(uint256 maxAllowed, uint256 balance, uint256 amount);

    ///@notice error emitido para notificar multiples intentos de ingreso
    error ReentrancyDenied(string errMessage);

    ///@notice error emitido cuando falla la transferencia
    error TransferFailed(bytes err);

    ///@notice error emitido cuando se intenta interactuar con el contrato mediante un llamado invalido
    error InvalidCallData(bytes receivedData);

    ///@notice error emitido cuando el retorno del oráculo es incorrecto
    error OracleCompromised(string errMessage);
    
    ///@notice error emitido cuando la última actualización del oráculo supera el heartbeat
    error OracleStalePrice(string errMessage);

    ///@notice error emitido bankCap no puede ser actualizado
    error BankCapacityUpdateFailed(uint256 newBankCap, uint256 currentStatus);

    ///@notice error emitido cuando no se puede otorgar un nuevo NFT
    error NftAlreadyMinted();

	/*///////////////////////
					Functions
	///////////////////////*/

	constructor(uint256 withdrawMaxAllowedEth
        , uint256 bankCap
        , uint256 minDepositRequiredFirstTimeEth
        , address feed
        , address usdc
        , address owner
    ) Ownable(owner)
    {
		_withdrawMaxAllowedEth = withdrawMaxAllowedEth;
        _bankCap = bankCap;
        _minDepositRequiredFirstTimeEth = minDepositRequiredFirstTimeEth;
        _feeds = AggregatorV3Interface(feed);
        _iUsdc = IERC20(usdc);
        _iEdp = new ETHDevPackNFT(owner, owner, address(this));

        _images[0] = "<https://red-random-tyrannosaurus-47.mypinata.cloud/ipfs/bafybeihpoh6rnl6twmbjbx2mhaeehc6w4yym63dqnt43dva4xbjtsby5q4/V.json>";
        _images[1] = "<https://red-random-tyrannosaurus-47.mypinata.cloud/ipfs/bafybeifrehnrdln5vsrg5xjxvtse5a4cemuyh4x2ruz6fdfrwcschbdcia/R.json>";
        _images[2] = "<https://red-random-tyrannosaurus-47.mypinata.cloud/ipfs/bafybeiblwmtxilhnliafzbr4e6kp3h4n76g7nhymsu6v4kubnrx2bs3f3a/GR.json>";
        _images[3] = "<https://red-random-tyrannosaurus-47.mypinata.cloud/ipfs/bafybeih474cyneuznkjejlskbrilrdyjjzzx3iyhqc6uwkwnfgr7ysbfei/G.json>";
	}
	
    /**
    *@notice función para evitar intentos maliciosos de exploit del contrato
	*/
	modifier PreventReentrancy()
    {
        if(_reentrancyLock)
        {
            revert ReentrancyDenied("Reentrancy denied");
        }

        _reentrancyLock = true;
        _;
        _reentrancyLock = false;
    }

    /*///////////////////////
        Public functions
    ///////////////////////*/
    
    /**
        *@notice Función que muestra el saldo general de la wallet que interactua con el contrato
        *@return El saldo en ETH, USDC y granteo de rewards de la billetera que interactua con el contracto
    */
    function getWalletGeneral() public view returns(uint256, uint256, bool)
    {
        uint256 amountInETH = uint256(vault[ethAddr][msg.sender].amount);
        uint256 amountInUSD = uint256(vault[usdcAddr][msg.sender].amount);

        return (amountInETH, amountInUSD, vault[ethAddr][msg.sender].rewardGranted);
    }
    
    /**
        *@notice Función que muestra el saldo en USD de la wallet que interactua con el contrato
        *@return El saldo de la billetera que interactua con el contracto
    */
    function getWalletBalanceInUSD() public view returns(uint256)
    {
        uint256 amountInUSD = ethToUsdc(uint256(vault[ethAddr][msg.sender].amount));
        amountInUSD += uint256(vault[usdcAddr][msg.sender].amount);     // Assume USDC/USD Ratio 1:1
        
        return amountInUSD;
    }

    /*///////////////////////
        External functions
    ///////////////////////*/
    
    ///@notice función para recibir solamente ETH sin datos de entrada (msg.data esta vacio)
	receive() external payable
    {
        _Deposit(Token.TOKEN_ETH);
    }
  
    ///@notice función fallback no permitida para recibir ETH. Rechaza el deposito.
	fallback() external payable 
    {
        revert InvalidCallData(msg.data);
    }
	
	/**
		*@notice función para recibir ETH
		*@dev esta función emite un evento para informar el correcto ingreso de ETH.
	*/
	function DepositEth() external payable 
    {
        _Deposit(Token.TOKEN_ETH);
	}

    /**
		*@notice función para recibir USDC
		*@dev esta función emite un evento para informar el correcto ingreso de USDC.
	*/
	function DepositUsdc() external payable 
    {
        _Deposit(Token.TOKEN_USDC);
	}

    /**
		*@notice función para retirar ETH
        *@param amount es el monto a retirar
		*@dev esta función debe emitir un evento informando el correcto egreso de ETH.
	*/
    function WithdrawEth(uint256 amount) external PreventReentrancy 
    {
        // Chequear limite de retiro
        if(!_InternalChecks(false, amount, Token.TOKEN_ETH))
        {
            revert WithdrawFailedEth(_withdrawMaxAllowedEth, vault[ethAddr][msg.sender].amount, amount);
        }
        
        // Chequear y premiar fidelidad
        if(_nftsGrantedByKipuBank < MAX_NFT &&  _CheckAndRewardFidelity())
        {
            emit AccountRewarded(msg.sender, "Felicidades! Has sido premiado con un NFT por tu fidelidad");
        }

        // Actualizar saldo
        vault[ethAddr][msg.sender].amount -= amount;

        if(vault[ethAddr][msg.sender].amount < vault[ethAddr][msg.sender].minBalance)
        {
            vault[ethAddr][msg.sender].minBalance = vault[ethAddr][msg.sender].amount;
        }
        
        // Proceder con el envio de ETH
        (bool succeed, bytes memory err) = msg.sender.call{value: amount}("");
        
        if(!succeed)
        {
            revert TransferFailed(err);
        }

        emit TransferSuccessful(msg.sender, "Retiro realizado con exito");

        // Actualizar variables de estado para trackeo interno
        _totalWithdrawsKipuBank++;
        _bankCapStatus -= amount;
    }

    /**
		*@notice función para retirar USDC
        *@param amount es el monto a retirar
		*@dev esta función debe emitir un evento informando el correcto egreso de USDC.
	*/
    function WithdrawUsdc(uint256 amount) external PreventReentrancy 
    {
        // Chequear limite de retiro
        if(!_InternalChecks(false, amount, Token.TOKEN_USDC))
        {
            revert WithdrawFailedUsdc(ethToUsdc(_withdrawMaxAllowedEth), vault[usdcAddr][msg.sender].amount, amount);
        }

        // Actualizar saldo
        vault[usdcAddr][msg.sender].amount -= amount;

        // Proceder con el envio de USDC
        (bool succeed, bytes memory err) = msg.sender.call{value: amount}("");
        
        if(!succeed)
        {
            revert TransferFailed(err);
        }

        emit TransferSuccessful(msg.sender, "Retiro realizado con exito");

        // Actualizar variables de estado para trackeo interno
        _totalWithdrawsKipuBank++;
        _bankCapStatus -= amount;
    }

    /**
     * @notice función para actualizar el monto maximo en ETH que KipuBank puede almacenar en su totalidad
     * @param newBankCap es el nuevo monto maximo en ETH tolerado por Kipubank
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

    /**
     * @notice función que informa al owner si una wallet especifica puede recibir NFT y si KipuBank dispone de NFT para otorgar
     * @param wallet es la billetera a consultar
     * @dev debe ser llamada solo por el propietario
     * @return devuelve tiempo en segundos entre firstDepositEth y el tiempo actual
     *  , flag indicando si la wallet puede recibir NFT
     *  , cantidad de NFTs que KipuBank ha emitido al momento
     *  , flag indicando si KipuBank dispone de NFTs para otorgar
     */
    function isWalletValidForGrantNft(address wallet) external view onlyOwner returns (uint256, bool, uint256, bool) 
    {
        bool areNftsFree = _nftsGrantedByKipuBank < MAX_NFT;
        bool walletValidForGrant = false;
        uint256 timeLapsed = block.timestamp - vault[ethAddr][wallet].timestampFirstDeposit;

        if (timeLapsed > TIME_LAPSED_TO_GRANT_NFT &&
            vault[ethAddr][wallet].minBalance >= _minDepositRequiredFirstTimeEth && 
            vault[ethAddr][wallet].rewardGranted == false)  
        {
            walletValidForGrant = true;
        }
        
        return(timeLapsed, walletValidForGrant, _nftsGrantedByKipuBank, areNftsFree);
    }

    /*///////////////////////
        Internal functions
    ///////////////////////*/
    
    /**
    * @notice función interna para realizar la conversión de decimales de ETH a USDC
    * @param _amount la cantidad de ETH a ser convertida
    * @return convertedAmount_ el resultado del cálculo de conversion a USDC.
    */
    function ethToUsdc(uint256 _amount) internal view returns (uint256 convertedAmount_) 
    {
        convertedAmount_ = (_amount * _ChainlinkFeed()) / DECIMAL_FACTOR;
    }

    /**
    * @notice función interna para realizar la conversión de decimales de USDC a ETH
    * @param _amount la cantidad de USDC a ser convertida
    * @return convertedAmount_ el resultado del cálculo de conversion a USDC.
    */
    function usdcToEth(uint256 _amount) internal view returns (uint256 convertedAmount_) 
    {
        convertedAmount_ = (_amount * DECIMAL_FACTOR) / _ChainlinkFeed();
    }

    /**
    * @notice función para consultar el precio en USD del ETH
    * @return el precio provisto por el oráculo.
    * @dev esta es una implementación simplificada, y no sigue completamente las buenas prácticas
    */
    function _ChainlinkFeed() internal view returns (uint256) 
    {
        (, int256 ethUSDPriceFetch, , uint256 updatedAt,) = _feeds.latestRoundData();

        if (ethUSDPriceFetch == 0) 
        {
            revert OracleCompromised("USDC price not fetched");
        }
        if (block.timestamp - updatedAt > ORACLE_HEARTBEAT) 
        {
            revert OracleStalePrice("USDC price staled");
        }

        return uint256(ethUSDPriceFetch);
    }

    /*///////////////////////
        Private functions
    ///////////////////////*/

    /**
        * @notice función interna que maneja el deposito de tokens
    */
    function _Deposit(Token token) private
    {
        address addr = ethAddr;
        if(token == Token.TOKEN_USDC)
        {
            addr = usdcAddr;
        }

        // Chequear capacidad de deposito de KipuBank
        if(!_InternalChecks(true, msg.value, token))
        {
            if(token == Token.TOKEN_ETH)
            {
                revert DepositFailedEth(_bankCap - _bankCapStatus, msg.value, _minDepositRequiredFirstTimeEth);
            }
            else if(token == Token.TOKEN_USDC)
            {
                revert DepositFailedUsdc(ethToUsdc(_bankCap - _bankCapStatus), msg.value);
            }
        }

        if(token == Token.TOKEN_ETH)
        {
            // Chequear si es primer deposito
            if(vault[addr][msg.sender].totalDeposits == 0)
            {
                vault[addr][msg.sender].timestampFirstDeposit = block.timestamp;
                vault[addr][msg.sender].minBalance = msg.value;
            }
            else 
            {
                // Chequear y premiar fidelidad otorgando un NFT
                if(_nftsGrantedByKipuBank < MAX_NFT &&  _CheckAndRewardFidelity())
                {
                    emit AccountRewarded(msg.sender, "Felicidades! Has sido premiado con un NFT por tu fidelidad");
                }
            }

            vault[addr][msg.sender].totalDeposits++;
        }

        // Actualizar billetera y emitir evento
		vault[addr][msg.sender].amount += msg.value;
		emit DepositSuccessful(msg.sender, "Deposito realizado con exito");

        // Actualizar totalDeposits para trackeo interno
        _totalDepositsKipuBank++;

        // Actualizar saldo de KipuBank para trackeo interno
        if(token == Token.TOKEN_ETH)
        {
            _bankCapStatus += msg.value;
        }        
        else if(token == Token.TOKEN_USDC)
        {
            _bankCapStatus += usdcToEth(msg.value);
        }
    }

    /**
        *@notice Función que chequea factibilidad de la solicitud
        *@param isDeposit para distinguir si es deposito u extraccion de tokens
        *@param amount es el monto involucrado en la operacion
        *@return isValid para notificar si es valida o no la solicitud
    */
    function _InternalChecks(bool isDeposit, uint256 amount, Token token) private view returns(bool)
    {
        address addr = ethAddr;
        uint256 withdrawMaxAllowed = _withdrawMaxAllowedEth;

        if(token == Token.TOKEN_USDC)
        {
            addr = usdcAddr;
            withdrawMaxAllowed = ethToUsdc(_withdrawMaxAllowedEth);
        }

        if(isDeposit)
        {
            if(token == Token.TOKEN_USDC)
            {
                amount = usdcToEth(amount);
            }

            //1- Chequear capacidad total de deposito de KipuBank
            if(_bankCapStatus + amount > _bankCap)
            {
                return false;
            }

            //2- Si es primer deposito en ETH el valor a depositar deber ser mayor a _minDepositRequiredFirstTimeEth
            if( token == Token.TOKEN_ETH &&
                vault[addr][msg.sender].totalDeposits == 0 && 
                amount < _minDepositRequiredFirstTimeEth)
            {
                return false;
            }
        }
        else 
        {
            //1- Chequear limite de extraccion permitido
            //2- Chequear que el saldo disponible sea mayor a lo que desea retirar
            if(amount > withdrawMaxAllowed ||
               amount > vault[addr][msg.sender].amount )
            {
                return false;
            }
        }

        return true;
    }

    /**
        *@notice Función que chequea si es factible el minteo de NFT (solo valido para ETH)
        *@return true para emitir notificacion de reward 
    */
    function _CheckAndRewardFidelity() private returns(bool) 
    {
        if( block.timestamp - vault[ethAddr][msg.sender].timestampFirstDeposit > TIME_LAPSED_TO_GRANT_NFT && 
            vault[ethAddr][msg.sender].minBalance >= _minDepositRequiredFirstTimeEth &&
            vault[ethAddr][msg.sender].rewardGranted == false)
        {
            // Check if can grant NFT
            if(_iEdp.balanceOf(msg.sender) > 0) 
            {
                revert NftAlreadyMinted();
            }

            // Emit NFT
            _iEdp.safeMint(msg.sender, _images[_nftsGrantedByKipuBank]);
            
            _nftsGrantedByKipuBank++;
            vault[ethAddr][msg.sender].rewardGranted = true;

            return true;
        }

        return false;
    }
}
