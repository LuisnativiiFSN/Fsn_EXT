<style>.page-header{margin:0 auto;font-family: Segoe UI Semibold;font-size: 10px;}.page-footer{margin-left: 50px;font-family:Segoe UI;font-size:9px}h1{font-size:28px}h2{font-size:26px}h3{font-size:23px}h4{font-size:22px}h5{font-size:20px}table{width:100%}#object-description{margin-top:-10px;margin-bottom:0px;}</style>

# FSN Integrations Methods


Codeunit 50053 FSN Integrations Methods.\
this codeunit is used to call the FSN Integrations to load data to BC

## Properties

| Property | Value |
| --- | --- |
| Object Type | Codeunit |
| Object Subtype | Normal |
| Object ID | 50053 |
| Accessibility Level | Public | 

## Procedures

### `getTransactionNo()`

getTransactionNo.\
Este metodo retorna el numero de transaccion para cargar los datos de la transaccion.


#### Syntax

```al
[Text[20]] := getTransactionNo(storeNo: Text[20], Terminal: Text[20])
```

#### Parameters

*storeNo*<br>
&emsp;Type: Text[20] <br>

string - max[20].

*Terminal*<br>
&emsp;Type: Text[20] <br>

string - max[20].


#### Return

*Text[20]*<br>

Retorna el codigo de la transaccion - string - max[20].

### `loadTransaction()`

loadTransaction.
cargar los datos de la transaccion.


#### Syntax

```al
[Boolean] := loadTransaction(json: Text)
```

#### Parameters

*json*<br>
&emsp;Type: Text <br>

string


#### Return

*Boolean*<br>

confirma si la transaccion termino de cargar toda la informacion - boolean

### `generateTerminalNo()`


#### Syntax

```al
[Text[20]] := generateTerminalNo(terminal: Text[20])
```

#### Parameters

*terminal*<br>
&emsp;Type: Text[20] <br>


