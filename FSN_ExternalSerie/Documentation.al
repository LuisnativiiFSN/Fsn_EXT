/*
- EVENT OnBeforeInsertItemLine: llama al procedimiento InsertCorrTK para isert del correlativo al escanear producto
- EVENT OnAfterStartNewTransaction: llama al procedimiento InsertCorrTK para insert del correlativo con el comando 'START'
- PROCEDURE ValidateSerie: Recibe codigo de serie y devuelve un boolean para valida que serie no este terminada.
- PROCEDURE InsertCorrTK: Recibe el RECORD Pos Transaction, Hace insert de correlativo al iniciar transaccion con comando START o  Escanear producto.
- PROCEDURE ValidateGigaUnoDocument: Recibe comando CCF y NCF para valida que exista numero de Serie y modificar serie en Pos Transaction
- EVENT OnAfterInsertTransHeader: Asigna numero de serie y informasion del cliente en Transaction Header.
- PROCEDURE  ModifySerie: Recibe codigo de serie y numero de serie para actualizar el ultimo utilizado al registrarse en Transaction Header
- PROCEDURE GigaUnoIsActive: Recibe Record POS Transaction y Valida que se encuentre activo gigaUno en parametro varios
- PROCEDURE ValidateDocumentType: Recibe Tipo de Documento para mostrar Tags en PV 
- EVENT OnProcessRefundSelection: Valida tipo documento para devolucion.
*/

