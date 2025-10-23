# KipuBankV2 - Entregable Modulo 3
## Descripcion del contrato

### Mejoras especificas de la V2
- El contrato __kipubankv2.sol__ permite la interaccion con wallets para el almacenamiento/extraccion de Ether y USDC.
- El contrato dispone de un owner que puede realizar funciones especificas
- El contrato otorga NFTs a modo de premio por fidelidad 

#### Funciones del owner
- Por defecto puede actualizar la wallet del ownership
- Tiene la posibilidad de modificar el limite total de ETH que KipuBank puede almacenar
- Puede chequear el limite actual, el saldo actual de depositos en ETH, la cantidad total de extracciones y de depositos
- Puede revisar wallets y observar si alguna es apta para recibir un NFT, cantidad de NFTs otorgados por KipuBank y si hay NFTs disponibles para otorgar

#### Premiacion con NFTs
- La premiacion con NFTs es solo valida para wallets que depositen ETH. La condicion es que la wallet realice un deposito minimo de 
ETH, definido durante el despliege del contrato, y que mantenga el saldo de ETH minimo al menos por el tiempo TIME_LAPSED_TO_GRANT_NFT. 
Se definio a TIME_LAPSED_TO_GRANT_NFT en 2 minutos para hacer pruebas. Se espera que este valor reprepesente un lapso de tiempo mayor. Ej: 3 meses.
- Solo se emite un NFT por wallet 
- KipuBank dispone de 4 NFTs en total para otorgar
- En caso de otorgar el NFT se emite un evento

#### Mejoras adicionales
- La wallet que interactua con el contrato puede ver el saldo en USD
- La wallet que interactua con el contrato puede ver sus ETH, USDC y si ha sido granteado con un NFT

Caracteristicas principales del contrato:
- Posee un limite de Ether a almacenar
- Limita la maxima cantidad de Ether/USDC a extraer en cada solicitud de retirada
- No limita el ingreso de Ether/USDC por wallet.
- Implementa eventos para notificar depositos y/o extracciones correctas
- Implementa errores para notificar depositos y/o extracciones fallidas
- Permite visualizar el saldo actual de la wallet que interactua con el contrato


# KipuBank - Entregable Modulo 2
## Descripcion del contrato

El contrato kipubank.sol permite la interaccion con wallets para el almacenamiento de Ether. Caracteristicas principales del contrato:

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
Contrato desplegado en [red de test Sepolia](https://sepolia.etherscan.io/address/0x84b2b6dd7b3cd6d240857b9372cc63a18c78309c#code)
