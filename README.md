# KipuBankV3 - Entregable Modulo 4
## Descripcion del contrato

### Mejoras especificas de la V3
- El contrato __kipubankv3.sol__ permite el deposito de tokens nativos como asi tambien de tokens ERC20.
- Todos los depositos se convierten automaticamente a USDC a excepcion de los depositos de tokens USDC que automaticamente se suman al balance de la wallet
depositante.
- Para el swap de tokens ERC20 se utiliza el router de UniswapV2
- Previo al deposito de los tokens, el contrato chequea si dispone de limite de almacenamiento de USDC en funcion a la variable __bankcap__. Se utiliza la funcion __getAmountsOut__ de la interfaz de Uniwasp para simular la cantidad de tokens que se recibirian para determinar si el limite es superado o no.
A la funcion de chequeo se le agrega un 5% de cantidad de USDC que se depositarian para cubrirse por las variaciones en el intercambio. De esta manera el contrato asegura que no se excedera el limite maximo de USDC que puede almacenar.
- Dado que todo lo que ingresa es convertido a USDC, el usuario dispone de la opcion de retiro solamente de USDC.
- Se mantienen las siguiente funciones de la V2:
  - Chequeo de saldo de wallet
  - Chequeo general de Kipubank (solo owner)
  - Cambio de limite de almacenamiento de USDC de Kipubank (solo owner)

### Cuestiones a mejorar en futuras versiones de kipubank
- La wallet que deposita tanto Ether como tokens ERC20 no puede corroborar el monto de USDC a obtener producto del swap es decir, cuando se ingresan los tokens el contrato hace la conversion de forma automatica sin solicitar confirmacion del monto a reicibir en USDC.
- La wallet que deposita tampoco puede establecer el limite de gas a utilizar en el swap.

Enlace de acceso al Block Explorer de Sepolia
-------------------------------------------------
Contrato desplegado en [red de test Sepolia](https://sepolia.etherscan.io/address/0xaf8aB759C50AB8f69b891fb4B0eca9E4cA0823EE#events)

**IMPORTANTE:** No ha sido posible verificar el contrato desde Remix a pesar de varios intentos, siempre se obtuvo una diferencia de bytes. API URL utilizada de Sepolia: https://api.etherscan.io/v2.

Direccion del contrato: 0xaf8aB759C50AB8f69b891fb4B0eca9E4cA0823EE
Input del constructor:
- withdrawMaxAllowed = 60000000;
- bankCap = 300000000;
- owner = 0x1D32FEDB0ed19584921221F3fAF148bD4128Ea70;
- uniswapV2Router = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;

**Pruebas:**
- El contrato fue testeado con deposito de Ether, USDC y LINK.
- El contrato fue testeado con retiro de USDC.

# KipuBankV2 - Entregable Modulo 3
## Descripcion del contrato

### Mejoras especificas de la V2
- El contrato __kipubankv2.sol__ permite la interaccion con wallets para el almacenamiento/extraccion de Ether y tokens ERC20.
- El contrato dispone de un owner que puede realizar funciones especificas:
  - incrementar/disminuir la capacidad de KipuBank
  - agregar, habilitar y deshabilitar tokens ERC20
- El contrato otorga NFTs a modo de premio por fidelidad en base a los Ether almacenados

#### Funciones del owner
- Por defecto puede actualizar la wallet del ownership
- Tiene la posibilidad de modificar el limite total de ETH que KipuBank puede almacenar
- Puede agregar nuevos tokens ERC20 asi como tambien habilitarlos y deshabilitarlos
- Puede chequear el limite actual, el saldo actual de depositos en ETH, la cantidad total de extracciones y de depositos
- Puede revisar wallets y observar si alguna es apta para recibir un NFT, cantidad de NFTs otorgados por KipuBank y si hay NFTs disponibles para otorgar

#### Premiacion con NFTs
- La premiacion con NFTs es solo valida para wallets que depositen ETH. La condicion es que la wallet realice un deposito minimo de
ETH, definido durante el despliege del contrato, y que mantenga el saldo de ETH minimo al menos por el tiempo _TIME_LAPSED_TO_GRANT_NFT_.
  Se definio a _TIME_LAPSED_TO_GRANT_NFT_ en 2 minutos para hacer pruebas. Se espera que este valor reprepesente un lapso de tiempo mayor. Ej: 3 meses.
- Solo se emite un NFT por wallet
- KipuBank dispone de 4 NFTs en total para otorgar
- En caso de otorgar el NFT se emite un evento

#### Mejoras adicionales
- La wallet que interactua con el contrato puede ver el saldo de tokens ERC20
- La wallet que interactua con el contrato puede ver sus ETH y si ha sido granteado con un NFT

#### Caracteristicas principales del contrato
- Chequea validez de deposito/extraccion de tokens ERC20
- Posee un limite de USD a almacenar
- Limita la maxima cantidad de Ether/USDC a extraer en cada solicitud de retirada
- No limita el ingreso de Ether/USDC por wallet.
- Implementa eventos para notificar depositos y/o extracciones correctas
- Implementa errores para notificar depositos y/o extracciones fallidas
- Permite visualizar el saldo actual de la wallet que interactua con el contrato

Enlace de acceso al Block Explorer de Sepolia
-------------------------------------------------
Contrato desplegado en [red de test Sepolia](https://sepolia.etherscan.io/address/0xc1A98e2a659D8b68C1155102206840CF837d3AaA)

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
