/*
    FSN CORRECTION DTE - HISTORICO FACTURA VENTA
    Solo lectura: no contiene UPDATE, INSERT ni DELETE.

    Escriba los valores que desea probar. Deje NULL cuando el campo no cambia.
*/

SET NOCOUNT ON;

DECLARE
    @DocumentoNo       NVARCHAR(20) = 'FC000000027'



/*--------------------------------------------------------------------------------------
    VALIDACION
--------------------------------------------------------------------------------------*/

-- Datos actuales del documento.
SELECT
    dte.[No_],
    dte.[DTE Invoice],
    dte.[DTE AuthNumber],
    dte.[Signature Validation],
    info.[External Document No_],
    info.[Posting Date]
FROM dbo.[FASANI$Sales Invoice Header$6961bd3e-336c-4dde-aeee-16842646cf34] dte
INNER JOIN dbo.[FASANI$Sales Invoice Header$437dbf0e-84ff-417a-965d-ed2bb9650972] info
    ON info.[No_] = dte.[No_]
WHERE @DocumentoNo IS NOT NULL
  AND dte.[No_] = @DocumentoNo;


/*--------------------------------------------------------------------------------------
    MODIFICACION - FILAS QUE SERIAN AFECTADAS

    DTE AuthNumber y Signature Validation solo afectan el encabezado DTE.
    Las tablas del DTE abreviado solo se afectan cuando cambia DTE Invoice.
--------------------------------------------------------------------------------------*/

SELECT
    [No_],
    [DTE Invoice],
    [DTE AuthNumber],
    [Signature Validation]
FROM dbo.[FASANI$Sales Invoice Header$6961bd3e-336c-4dde-aeee-16842646cf34]
WHERE @DocumentoNo IS NOT NULL
  AND [No_] = @DocumentoNo;

SELECT
    [No_],
    [External Document No_]
FROM dbo.[FASANI$Sales Invoice Header$437dbf0e-84ff-417a-965d-ed2bb9650972]
WHERE @DocumentoNo IS NOT NULL
  AND [No_] = @DocumentoNo;

-- Movimientos de cliente. Solo se modifican registros cuyo valor actual no esta vacio.
SELECT
    [Entry No_],
    [Document No_],
    [Document Type],
    [External Document No_]
FROM dbo.[FASANI$Cust_ Ledger Entry$437dbf0e-84ff-417a-965d-ed2bb9650972]
WHERE [Document No_] = @DocumentoNo
  AND [Document Type] = 2
  AND [External Document No_] <> N'';

-- Movimientos contables de ventas. Se modifican todas las filas encontradas.
SELECT
    [Entry No_],
    [Document No_],
    [Document Type],
    [Source Code],
    [External Document No_]
FROM dbo.[FASANI$G_L Entry$437dbf0e-84ff-417a-965d-ed2bb9650972]
WHERE [Document No_] = @DocumentoNo
  AND [Document Type] = 2
  AND [Source Code] = N'VENTAS'
  AND [External Document No_] <> N'';

-- Documento legal de factura de venta.
SELECT

    [No_],
    [Sub Type],
    [External Document No_]
FROM dbo.[FASANI$Legal Ledger Entry$c2ec0fd9-a04f-49ff-8054-df8b17008af7]
WHERE [No_] = @DocumentoNo
  AND [Sub Type] = N'FACT-V'
  AND [External Document No_] <> N'';
