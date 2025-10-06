//SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
	*@title KipuBank
	*@notice contrato correspondiente al entregable final del Modulo2
	*@author mguarna
	*@custom:security Contrato con fines educativos. No usar en producción.
*/
contract KipuBank {

	/*///////////////////////
					Variables
	///////////////////////*/
	///@notice variable inmutable para establecer limite de retiro de fondos
	uint256 private immutable _withdrawMaxAllowed;
    
    ///@notice variable inmutable para establecer limite global de depositos
    uint256 private immutable _bankCap;

    ///@notice variable para controlar el estado actual de los depositos
    uint256 private _bankCapStatus;

    ///@notice variables para llevar el control del numero total de depositos
    uint256 totalDeposits;
    
    ///@notice variables para llevar el control del numero total de extracciones
    uint256 totalWithdraws;

    //@notice variable para blockear intentos de reentrancia
    bool private reentrancyLock;

	///@notice mapping para almacenar cuentas de usuario y su saldo
	mapping(address userAccount => uint256 amount) vault;
	
	/*///////////////////////
						Events
	////////////////////////*/
    ///@notice evento emitido cuando el deposito fue exitoso
	event DepositSuccessful(address wallet, string msg);

    ///@notice evento emitido cuando la extraccion fue exitosa
    event TransferSuccessful(address wallet, string msg);

	/*///////////////////////
						Errors
	///////////////////////*/
	///@notice error emitido cuando falla el intento de deposito de ETH
	error DepositFailed(uint256 permitted, uint256 amount);
	
    ///@notice error emitido cuando falla el intento de extraccion de ETH
	error WithdrawFailed(uint256 maxAllowed, uint256 balance, uint256 amount);

    ///@notice error emitido para notificar multiples intentos de ingreso
    error ReentrancyDenied(string errMessage);

    ///@notice error emitido cuando falla la transferencia
    error TransferFailed(bytes err);

    ///@notice error emitido cuando se intenta interactuar con el contrato mediante un llamado invalido
    error InvalidCallData(bytes receivedData);
	
	/*///////////////////////
					Functions
	///////////////////////*/
	constructor(uint256 withdrawMaxAllowed, uint256 bankCap)
    {
		_withdrawMaxAllowed = withdrawMaxAllowed;
        _bankCap = bankCap;
	}
	
    /**
    *@notice función para evitar intentos maliciosos de exploit del contrato
	*/
	modifier PreventReentrancy()
    {
        if(reentrancyLock)
        {
            revert ReentrancyDenied("Reentrancy denied");
        }

        reentrancyLock = true;
        _;
        reentrancyLock = false;
    }

	///@notice función para recibir ETH directamente sin datos de entrada (msg.data esta vacio)
	receive() external payable
    {
        // Chequear capacidad de deposito de KipuBank
        if (!_InternalChecks(true, msg.value))
        {
           revert DepositFailed(_bankCap - _bankCapStatus, msg.value);
        }

        // Actualizar billetera y emitir evento
		vault[msg.sender] += msg.value;
		emit DepositSuccessful(msg.sender, "Deposito exitoso");

        // Actualizar variables de estado para trackeo interno
        totalDeposits++;
        _bankCapStatus += msg.value;
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
	function Deposit() external payable 
    {
        // Chequear capacidad de deposito de KipuBank
        if(!_InternalChecks(true, msg.value))
        {
            revert DepositFailed(_bankCap - _bankCapStatus, msg.value);
        }

        // Actualizar billetera y emitir evento
		vault[msg.sender] += msg.value;
		emit DepositSuccessful(msg.sender, "Deposito realizado con exito");

        // Actualizar variables de estado para trackeo interno
        totalDeposits++;
        _bankCapStatus += msg.value;
	}
	
    /**
		*@notice función para retirar ETH
        *@param amount es el monto a retirar
		*@dev esta función debe emitir un evento informando el correcto egreso de ETH.
	*/
    function Withdraw(uint256 amount) external PreventReentrancy 
    {
        // Chequear limite de retiro
        if(!_InternalChecks(false, amount))
        {
            revert WithdrawFailed(_withdrawMaxAllowed, vault[msg.sender], amount);
        }
        
        // Actualizar saldo
        vault[msg.sender] -= amount;
        
        // Proceder con el envio de ETH
        (bool succeed, bytes memory err) = msg.sender.call{value: amount}("");
        
        if(!succeed)
        {
            revert TransferFailed(err);
        }

        emit TransferSuccessful(msg.sender, "Retiro realizado con exito");

        // Actualizar variables de estado para trackeo interno
        totalWithdraws++;
        _bankCapStatus -= amount;
    }

    /**
        *@notice Función que chequea factibilidad de la solicitud
        *@param isDeposit para distinguir si es deposito u extraccion de ETH
        *@param amount es el monto involucrado en la operacion
        *@return isValid para notificar si es valida o no la solicitud
    */
    function _InternalChecks(bool isDeposit, uint256 amount) private view returns(bool)
    {
        if(isDeposit)
        {
            //1- Chequear capacidad de deposito de KipuBank
            if(_bankCapStatus + amount > _bankCap)
            {
                return false;
            }
        }
        else 
        {
            //1- Chequear limite de extraccion permitido
            //2- Chequear que el saldo disponible sea mayor a lo que desea retirar
            if(amount > _withdrawMaxAllowed ||
               amount > vault[msg.sender] )
            {
                return false;
            }
        }

        return true;
    }

    /**
        *@notice Función que indica la totalidad de movimientos
        *@return El saldo de la billetera que interactua con el contracto
    */
    function Balance() public view returns(uint256)
    {
        return vault[msg.sender];
    }
}
