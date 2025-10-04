# KipuBank - Entregable Modulo 2
## Descripcion del contrato
El contrato __kipubank.sol__ permite la interaccion con wallets para el almacenamiento de Ether.
- Posee un limite de Ether a almacenar que se define al momento de su despliege.
- Limita la maxima cantidad de Ether a extraer en cada solicitud de retirada
- No limita el ingreso de Ether por wallet.
- Implementa eventos para notificar depositos y/o extracciones correctas
- Implementa errores para notificar depositos y/o extracciones fallidas
- Permite visualizar el saldo actual de la wallet que interactua con el contrato

Despliegue del contrato
-----------------------------
1. Copiar la URL del repositorio 
2. Ir a Remix y logguearse a Github 
3. Seleccionar la opcion Clone y colocar la URL del repositorio.
4. Seleccionar el contrato en Remix.
5. Dirigirse al tab de _Deploy & Run Transactions_ y configurar el _ENVIRONMENT_ agregando su billetera Metamask. Ya que estamos en entorno 
de prueba trabajamos con la red Sepolia.
6. Dirigirse al tab _Solidity Compiler_, verificar que la version del compiler selccionada coincida con la definida en el contracto.
7. Cliquear en el boton _COMPILE_. Asegurarse que aparezca el check en verde para continuar.
8. Volver a _Deploy & Run Transactions_ agregar los datos de withdrawMaxAllowed y bankCap y ejecutar el _Deploy_. Aceptar la transaccion desde la billetera.

Interaccion con el contrato
-----------------------------
9. Con el contrato ya desplegado dirigirse a la opcion _Deployed Contracts_ y probar las diferentes opciones disponibles
   - Deposit (Rojo): Para depositar Ether cargandolos previamente en la opcion VALUE
   - Withdraw (Naranja): Para colocar la cantidad de Ether a extraer
   - Balance (Azul): Para visualizar el saldo disponible 


Enlace de acceso al Block Explorer de Sepolia
-------------------------------------------------
Contrato desplegado en [red de test Sepolia]([https://sepolia.etherscan.io/tx/0x1df566d76e61fab34007282fc67b5d5a8dd4ceff2ff8a5c3697bd509796f788e](https://sepolia.etherscan.io/tx/0x460409b9b8958da98138488814f952345f44bbaf6f7628f94d6b8d128db123d5))
