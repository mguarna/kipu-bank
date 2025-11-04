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

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

address constant ethAddr = address(0x0000000000000000000000000000000000000000);

/**
	*@title KipuBankV2
	*@notice contrato correspondiente al entregable final del Modulo3
	*@author mguarna
	*@custom:security Contrato con fines educativos. No usar en producción.
*/
contract KipuBankV2 is Ownable, ReentrancyGuard {
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
	uint256 private immutable _withdrawMaxAllowed;
    
    ///@notice variable inmutable para establecer el monto minimo a depositar para abrir una cuenta
    uint256 private immutable _minDepositRequiredFirstTimeEth;

    ///@notice variable para establecer limite global de depositos en USD
    uint256 private _bankCap;

    ///@notice variable para controlar el estado actual de los depositos en USD
    uint256 private _bankCapStatus;

    ///@notice variable para llevar el control del numero total de depositos en kipuBank
    uint256 private _totalDepositsKipuBank;
    
    ///@notice variable para llevar el control del numero total de extracciones
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

	///@notice mapping para almacenar cuentas de usuario y sus movimientos en diferentes tokens
    mapping(address => mapping(address userAccount => AccountState)) vault;

    /// @notice Estructura para guardar la información de cada token ERC20 soportado
    struct TokenConfig {
        IERC20 token;                        // Contrato ERC20
        AggregatorV3Interface priceFeed;     // Oráculo de precio (TokenERC20/ETH)
        uint8 decimals;                      // Decimales del feed
        bool supported;                      // Si el token existe
        bool status;                         // Si el token esta habilitado para su uso
    }

    /// @notice Mapping de dirección del token ERC20 → configuración
    mapping(address => TokenConfig) public tokenConfigs;
  
    ///@notice variable inmutable para almacenar el NFT de EDP
    ETHDevPackNFT immutable _iEdp;

    ///@notice variable para almacenar la dirección del Chainlink Feed ETH/USD (Sepolia)
    ///@dev 0x694AA1769357215DE4FAC081bf1f309aDC325306 Ethereum 
    AggregatorV3Interface public ethUsdPriceFeed;

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

    ///@notice error emitido cuando falla el intento de deposito de tokens por falta de capacidad de KipuBank
    error KipuBankWithoutCapacity(string errMessage);
	
    ///@notice error emitido cuando falla el intento de extraccion de ETH
	error WithdrawFailedEth(uint256 maxAllowed, uint256 balance, uint256 amount);

    ///@notice error emitido cuando falla el intento de extraccion de tokens ERC20
	error WithdrawFailedErc20(uint256 maxAllowed, uint256 balance, uint256 amount, address addr);

    ///@notice error emitido para notificar multiples intentos de ingreso
    error ReentrancyDenied(string errMessage);

    ///@notice error emitido cuando falla la transferencia
    error TransferFailed(bytes err);

    ///@notice error emitido cuando se intenta interactuar con el contrato mediante un llamado invalido
    error InvalidReceiveCall(string errMessage);

    ///@notice error emitido cuando se intenta interactuar con el contrato mediante un llamado invalido
    error InvalidCallData(bytes receivedData);

    ///@notice error emitido cuando el retorno del oráculo es incorrecto
    error OracleCompromised(string errMessage);
    
    ///@notice error emitido cuando la última actualización del oráculo supera el heartbeat
    error OracleStalePrice(string errMessage);

    ///@notice error emitido cuando no existe ronda valida
    error OracleUnanswerRound(string errMessage);

    ///@notice error emitido bankCap no puede ser actualizado
    error BankCapacityUpdateFailed(uint256 newBankCap, uint256 currentStatus);

    ///@notice error emitido cuando no se puede otorgar un nuevo NFT
    error NftAlreadyMinted();

	/*///////////////////////
					Functions
	///////////////////////*/

	constructor(uint256 withdrawMaxAllowed
        , uint256 bankCap
        , uint256 minDepositRequiredFirstTimeEth
        , address owner
    ) Ownable(owner)
    {
		_withdrawMaxAllowed = withdrawMaxAllowed;
        _bankCap = bankCap;
        _minDepositRequiredFirstTimeEth = minDepositRequiredFirstTimeEth;
        _iEdp = new ETHDevPackNFT(owner, owner, address(this));

        _images[0] = "<https://red-random-tyrannosaurus-47.mypinata.cloud/ipfs/bafybeihpoh6rnl6twmbjbx2mhaeehc6w4yym63dqnt43dva4xbjtsby5q4/V.json>";
        _images[1] = "<https://red-random-tyrannosaurus-47.mypinata.cloud/ipfs/bafybeifrehnrdln5vsrg5xjxvtse5a4cemuyh4x2ruz6fdfrwcschbdcia/R.json>";
        _images[2] = "<https://red-random-tyrannosaurus-47.mypinata.cloud/ipfs/bafybeiblwmtxilhnliafzbr4e6kp3h4n76g7nhymsu6v4kubnrx2bs3f3a/GR.json>";
        _images[3] = "<https://red-random-tyrannosaurus-47.mypinata.cloud/ipfs/bafybeih474cyneuznkjejlskbrilrdyjjzzx3iyhqc6uwkwnfgr7ysbfei/G.json>";

        // ETH/USD feed address (Sepolia)
        ethUsdPriceFeed = AggregatorV3Interface(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        
        // LINK / ETH
        tokenConfigs[0xb4c4a493AB6356497713A78FFA6c60FB53517c63] = TokenConfig(
        {
            token: IERC20(0xb4c4a493AB6356497713A78FFA6c60FB53517c63), 
            priceFeed: AggregatorV3Interface(0xb4c4a493AB6356497713A78FFA6c60FB53517c63),
            decimals: 18,
            supported: true,
            status: true
        });

        // UNI / ETH
        tokenConfigs[0x553303d460EE0afB37EdFf9bE42922D8FF63220e] = TokenConfig(
        {
            token: IERC20(0x553303d460EE0afB37EdFf9bE42922D8FF63220e),
            priceFeed: AggregatorV3Interface(0x553303d460EE0afB37EdFf9bE42922D8FF63220e),
            decimals: 18,
            supported: true,
            status: false
        });

        // USDC / ETH
        tokenConfigs[0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238] = TokenConfig(
        {
            token: IERC20(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238),
            priceFeed: AggregatorV3Interface(0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238),
            decimals: 8,
            supported: true,
            status: true
        });
	}
	
    /*///////////////////////
        Public functions
    ///////////////////////*/
    
    /**
        *@notice Función que muestra el saldo en Ether de la wallet que interactua con el contrato
        *@return El saldo en ETH y granteo de rewards de la billetera que interactua con el contracto
    */
    function getWalletEth() public view returns(uint256, bool)
    {
        uint256 amountInETH = uint256(vault[ethAddr][msg.sender].amount);
        return (amountInETH, vault[ethAddr][msg.sender].rewardGranted);
    }
    
    /**
        *@notice Función que muestra el saldo tokens de una wallet en especifico
        *@param _tokenAddr la direccion del token ERC20
        *@param _wallet la direccion de la billetera a consultar saldo
        *@return El saldo de tokens ERC20
    */
    function balanceOf(address _tokenAddr, address _wallet) public view returns (uint256) 
    {
        return vault[_tokenAddr][_wallet].amount;
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
		*@notice función para recibir ETH
		*@notice esta función emite un evento para informar el correcto ingreso de ETH.
	*/
	function DepositEth() external payable nonReentrant
    {
        bool bankStatus = _HasCapacityKipuBank(ethToUsd(msg.value));
        if (!bankStatus)
        {
            revert KipuBankWithoutCapacity("KipuBank has no capacity to store more tokens");
        }
        
        if (vault[ethAddr][msg.sender].totalDeposits == 0 && 
            msg.value < _minDepositRequiredFirstTimeEth)
        {
            revert DepositFailedEth(_bankCap - _bankCapStatus, msg.value, _minDepositRequiredFirstTimeEth);
        }

        // Chequear si es primer deposito
        if(vault[ethAddr][msg.sender].totalDeposits == 0)
        {
            vault[ethAddr][msg.sender].timestampFirstDeposit = block.timestamp;
            vault[ethAddr][msg.sender].minBalance = msg.value;
        }
        else 
        {
            // Chequear y premiar fidelidad otorgando un NFT
            if(_nftsGrantedByKipuBank < MAX_NFT &&  _CheckAndRewardFidelity())
            {
                emit AccountRewarded(msg.sender, "Felicidades! Has sido premiado con un NFT por tu fidelidad");
            }
        }

        vault[ethAddr][msg.sender].totalDeposits++;

        // Actualizar totalDeposits para trackeo interno
        _totalDepositsKipuBank++;

        // Update total balance (USD)
        _bankCapStatus += ethToUsd(msg.value);

        // Actualizar billetera y emitir evento
		vault[ethAddr][msg.sender].amount += msg.value;
		emit DepositSuccessful(msg.sender, "Deposito realizado con exito");  
	}

    /**
     * @notice función externa para recibir depósitos de tokens ERC20
     * @notice esta función emite un evento para informar el correcto ingreso de tokens ERC20.
     * @param _amount la cantidad a ser depositada.
     * @param _erc20Addr the input ERC20 token address
    */
    function DepositErc20(uint256 _amount, address _erc20Addr) external nonReentrant {

        TokenConfig memory config = tokenConfigs[_erc20Addr];
        if (!config.supported)
        {
             revert("Token ERC20 not supported by KipuBank");
        }

        IERC20 _iErc20 = IERC20(_erc20Addr);
        uint256 allowance_ = _iErc20.allowance(msg.sender, address(this));
        if (allowance_ < _amount) 
        {
            revert("DepositErc20: allowance insufficient");
        }

        // Convert tokens ERC20 -> ETH -> USD
        uint256 _amountInEth = erc20ToEth(_amount, config.priceFeed, config.decimals);
        uint256 _amountInUsd = ethToUsd(_amountInEth);
        bool bankStatus = _HasCapacityKipuBank(_amountInUsd);
        if(!bankStatus)
        {
            revert KipuBankWithoutCapacity("KipuBank has no capacity to store more tokens");
        }
        
        _iErc20.safeTransferFrom(msg.sender, address(this), _amount);
        
        // Update total balance (USD)
        _bankCapStatus += _amount;

        // Actualizar totalDeposits para trackeo interno
        _totalDepositsKipuBank++;

        // Actualizar billetera y emitir evento
		vault[_erc20Addr][msg.sender].amount += _amount;
		emit DepositSuccessful(msg.sender, "Deposito realizado con exito");
    }

    /**
		*@notice función para retirar ETH protegida contra reentrancy
        *@param _amount es el monto a retirar
		*@dev esta función debe emitir un evento informando el correcto egreso de ETH.
	*/
    function WithdrawEth(uint256 _amount) external nonReentrant 
    {
        // Chequear validez del monto a retirar
        uint256 _amountInUsd = ethToUsd(_amount);
        bool isAllowed = _IsWithdrawAllowed(_amountInUsd, _amount, ethAddr);
        if(!isAllowed)
        {
            revert WithdrawFailedEth(usdToEth(_withdrawMaxAllowed), vault[ethAddr][msg.sender].amount, _amount);
        }
        
        // Chequear y premiar fidelidad
        if(_nftsGrantedByKipuBank < MAX_NFT &&  _CheckAndRewardFidelity())
        {
            emit AccountRewarded(msg.sender, "Felicidades! Has sido premiado con un NFT por tu fidelidad");
        }

        // Actualizar saldo antes de enviar
        vault[ethAddr][msg.sender].amount -= _amount;

        if(!vault[ethAddr][msg.sender].rewardGranted &&
            vault[ethAddr][msg.sender].amount < vault[ethAddr][msg.sender].minBalance)
        {
            vault[ethAddr][msg.sender].minBalance = vault[ethAddr][msg.sender].amount;
        }
        
        // Proceder con el envio de ETH
        (bool succeed, bytes memory err) = msg.sender.call{value: _amount}("");
        
        if(!succeed)
        {
            revert TransferFailed(err);
        }

        emit TransferSuccessful(msg.sender, "Retiro realizado con exito");

        // Actualizar variables de estado para trackeo interno
        _totalWithdrawsKipuBank++;
        _bankCapStatus -= ethToUsd(_amount);
    }

    /**
		*@notice función para retirar tokens ERC20 protegida contra reentrancy
        *@param _amount es el monto a retirar
		*@dev esta función debe emitir un evento informando el correcto egreso de tokens ERC20.
	*/
    function WithdrawErc20(uint256 _amount, address _erc20Addr) external nonReentrant 
    {
        TokenConfig memory config = tokenConfigs[_erc20Addr];
        if (!config.supported)
        {
            revert("Token ERC20 not supported by KipuBank");
        }

        // Chequear validez del monto a retirar
        // Convert tokens ERC20 -> ETH -> USD
        uint256 _amountInEth = erc20ToEth(_amount, config.priceFeed, config.decimals);
        uint256 _amountInUsd = ethToUsd(_amountInEth);
        
        bool isAllowed = _IsWithdrawAllowed(_amountInUsd, _amount, _erc20Addr);
        if(!isAllowed)
        {
            revert WithdrawFailedErc20(_withdrawMaxAllowed, vault[_erc20Addr][msg.sender].amount, _amount, _erc20Addr);
        }

        // Actualizar saldo antes de enviar
        vault[_erc20Addr][msg.sender].amount -= _amount;

        // Proceder con el envio de ERC20
        (bool succeed, bytes memory err) = msg.sender.call{value: _amount}("");
        
        if(!succeed)
        {
            revert TransferFailed(err);
        }

        emit TransferSuccessful(msg.sender, "Retiro realizado con exito");

        // Actualizar variables de estado para trackeo interno
        _totalWithdrawsKipuBank++;
        // TODO Update amount to USD
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
     * @notice función que permite incluir/actualizar tokens ERC20 en KipuBank
     * @param _token la direccion del token ERC20
     * @param _feed correspondiente al token ERC20 / ETH (de la red Sepolia en nuestro entorno dev)
     * @param _decimals decimales del token
     * @param _enabled para indicar si esta habilitado o no
     */
    function upsertTokenERC20(address _token, address _feed, uint8 _decimals, bool _enabled) external onlyOwner 
    {
        
        TokenConfig memory config = tokenConfigs[_token];

        // Actualizar estado de token ERC20 existente
        if (config.supported == true && config.status != _enabled)
        {
            config.status = _enabled;
        }

        // Agregar nuevo token ERC20 a KipuBank
        else
        {
            tokenConfigs[_token] = TokenConfig({
                token: IERC20(_token),
                priceFeed: AggregatorV3Interface(_feed),
                decimals: _decimals,
                supported: true,
                status: _enabled
            });
        }
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
    * @notice función interna para realizar la conversión de decimales de ETH a USD
    * @param _amount la cantidad de ETH a ser convertida
    * @return _convertedAmount el resultado del cálculo de conversion a USD.
    */
    function ethToUsd(uint256 _amount) internal view returns (uint256 _convertedAmount) 
    {
        _convertedAmount = (_amount * _ChainlinkFeed(ethUsdPriceFeed)) / DECIMAL_FACTOR;
    }

    /**
    * @notice función interna para realizar la conversión de decimales de USD a ETH
    * @param _amount la cantidad de USD a ser convertida
    * @return _convertedAmount el resultado del cálculo de conversion a USD.
    */
    function usdToEth(uint256 _amount) internal view returns (uint256 _convertedAmount) 
    {
        _convertedAmount = (_amount * DECIMAL_FACTOR) / _ChainlinkFeed(ethUsdPriceFeed);
    }

    /**
    * @notice función para convertir tokens ERC20 a ETH
    * @param _amount la cantidad de tokens ERC20 a ser convertida
    * @param feed correspondiente a ERC20 / ETH (Sepolia)
    * @param feedDecimals la cantidad de decimales del ERC20
    * @return el amount equivalente en Ether
    */
    function erc20ToEth(uint256 _amount, AggregatorV3Interface feed, uint256 feedDecimals) internal view returns (uint256) 
    {
        uint256 amountInEth = (_amount * uint256(_ChainlinkFeed(feed))) / (10 ** feedDecimals);

        return amountInEth;
    }

    /**
    * @notice función para consultar el precio en USD del ETH
    * @return el precio provisto por el oráculo.
    * @dev esta es una implementación simplificada, y no sigue completamente las buenas prácticas
    */
    function _ChainlinkFeed(AggregatorV3Interface feed) internal view returns (uint256) 
    {
        (   uint256 roundId
            ,  int256 priceFetched
            , // startedAt
            , uint256 updatedAt
            , uint256 answeredInRound
        ) = feed.latestRoundData();

        if (priceFetched == 0) 
        {
            revert OracleCompromised("USDC price not fetched");
        }
        else if (block.timestamp - updatedAt > ORACLE_HEARTBEAT) 
        {
            revert OracleStalePrice("USDC price staled");
        }
        else if (answeredInRound < roundId)
        {
            revert OracleUnanswerRound("Round without valid response");
        }

        return uint256(priceFetched);
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
        *@param amountInUsd la cantidad equivalente en USD que se solicita retirar
        *@param amount la cantidad de tokens que se solicita retirar
        *@return true para informar que se puede realizar retiro
    */
    function _IsWithdrawAllowed(uint256 amountInUsd, uint256 amount, address tokenAddr) private view returns(bool)
    {
            //1- Chequear limite de extraccion permitido
            //2- Chequear que el saldo disponible sea mayor a lo que desea retirar
            if(amountInUsd > _withdrawMaxAllowed ||
               amount > vault[tokenAddr][msg.sender].amount)
            {
                return false;
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
