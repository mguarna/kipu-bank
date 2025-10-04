//SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
	*@title KipuBank
	*@notice contrato correspondiente al entregable final del Modulo2
	*@author mguarna
	*@custom:security Contrato con fines educativos. No usar en producción.
*/
contract Kipubank {

	/*///////////////////////
					Variables
	///////////////////////*/
	///@notice variable inmutable para establecer limite de retiro de fondos
	uint256 private immutable _withdrawMaxAllowed;
    
    ///@notice variable inmutable para establecer limite global de depositos
    uint256 private immutable _bankCap;

    ///@notice variable para controlar el estado actual de los depositos
    uint256 private _bankCapStatus;

    ///@notice variables para llevar el control del numero depositos y extracciones
    uint256 totalWithdraws;
    uint256 totalDeposits;

    //@notice variable para blockear intentos de reentrancia
    bool private reentrancyLock;

	///@notice mapping para almacenar cuentas de usuario y su saldo
	mapping(address userAccount => uint256 amount) vault;
	
	/*///////////////////////
						Events
	////////////////////////*/
    ///@notice evento emitido cuando el deposito/extraccion fue exitoso
	event OperationSucceed(address wallet, string msg);

	/*///////////////////////
						Errors
	///////////////////////*/
	///@notice error emitido cuando falla el intento de deposito de ETH
	error DepositFailed(uint256 permitted, uint256 amount);
	///@notice error emitido cuando falla el intento de extraccion de ETH
	error WithdrawFailed(uint256 maxAllowed, uint256 balance, uint256 amount);
	
	/*///////////////////////
					Functions
	///////////////////////*/
	constructor(uint256 withdrawMaxAllowed, uint256 bankCap)
    {
		_withdrawMaxAllowed = withdrawMaxAllowed;
        _bankCap = bankCap;
        _bankCapStatus = 0;
        totalWithdraws = 0;
        totalDeposits = 0;
        reentrancyLock = false;
	}
	
	modifier PreventReentrancy()
    {
        require(!reentrancyLock, "Reentrancy denied");
        reentrancyLock = true;
        _;
        reentrancyLock = false;
    }

	///@notice función para recibir ETH directamente sin datos de entrada (msg.data esta vacio)
	receive() external payable
    {
        // Chequear capacidad de deposito de KipuBank
        require(_InternalChecks(true, msg.value), DepositFailed(_bankCap - _bankCapStatus, msg.value));

        // Actualizar billetera y emitir evento
		vault[msg.sender] += msg.value;
		emit OperationSucceed(msg.sender, "Deposito exitoso");

        // Actualizar variables de estado para trackeo interno
        totalDeposits++;
        _bankCapStatus += msg.value;
    }

    ///@notice función para recibir ETH directamente con datos de entrada (msg.data valido) pero 
    // no hay coincidencia con otras funciones - No implemento fallback
	fallback() external{}
	
	/**
		*@notice función para recibir ETH
		*@dev esta función emite un evento para informar el correcto ingreso de ETH.
	*/
	function Deposit() external payable 
    {
        // Chequear capacidad de deposito de KipuBank
        require(_InternalChecks(true, msg.value), DepositFailed(_bankCap - _bankCapStatus, msg.value));

        // Actualizar billetera y emitir evento
		vault[msg.sender] += msg.value;
		emit OperationSucceed(msg.sender, "Deposito realizado con exito");

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
        require(_InternalChecks(false, amount), WithdrawFailed(_withdrawMaxAllowed, vault[msg.sender], amount));
        
        // Actualizar saldo
        vault[msg.sender] -= amount;
        
        // Proceder con el envio de ETH
        (bool succeed, ) = msg.sender.call{value: amount}("");
        require(succeed, "Transferencia fallida");
        emit OperationSucceed(msg.sender, "Retiro realizado con exito");

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
