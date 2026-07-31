/*
    FSN CORRECTION DTE - HISTORICO FACTURA COMPRA
    Solo lectura: no contiene UPDATE, INSERT ni DELETE.

    Escriba los valores que desea probar. Deje NULL cuando el campo no cambia.
*/

SET NOCOUNT ON;

DECLARE
    @DocumentoNo       NVARCHAR(20) = N'FAC0000052081'



/*--------------------------------------------------------------------------------------
    VALIDACION
--------------------------------------------------------------------------------------*/

-- Datos actuales: DTE, proveedor, pedido y DTE abreviado.
SELECT
    dte.[No_],
    dte.[DTE Invoice],
    dte.[DTE AuthNumber],
    dte.[Signature Validation],
    info.[Buy-from Vendor No_],
    info.[Vendor Invoice No_],
    info.[Order No_],
    info.[Posting Date],
    info.[Document Date],
    info.[Source Code]
FROM dbo.[FASANI$Purch_ Inv_ Header$6961bd3e-336c-4dde-aeee-16842646cf34] dte
INNER JOIN dbo.[FASANI$Purch_ Inv_ Header$437dbf0e-84ff-417a-965d-ed2bb9650972] info
    ON info.[No_] = dte.[No_]
WHERE dte.[No_] = @DocumentoNo;

-- Obtener el HRC exacto cruzando las lineas de factura y recepcion.
SELECT DISTINCT
    factura.[Document Date],
    recepcionLinea.[Location Code],
    recepcionLinea.[Buy-from Vendor No_] AS [Proveedor],
    recepcionLinea.[Document No_] AS [Recepcion],
    factura.[No_] AS [Factura Interna]
FROM dbo.[FASANI$Purch_ Rcpt_ Line$437dbf0e-84ff-417a-965d-ed2bb9650972] recepcionLinea
INNER JOIN dbo.[FASANI$Purch_ Inv_ Line$437dbf0e-84ff-417a-965d-ed2bb9650972] facturaLinea
    ON recepcionLinea.[Order No_] = facturaLinea.[Order No_]
   AND recepcionLinea.[No_] = facturaLinea.[No_]
   AND recepcionLinea.[Quantity] = facturaLinea.[Quantity]
   AND facturaLinea.[Quantity] <> 0
INNER JOIN dbo.[FASANI$Purch_ Inv_ Header$437dbf0e-84ff-417a-965d-ed2bb9650972] factura
    ON facturaLinea.[Document No_] = factura.[No_]
WHERE factura.[No_] = @DocumentoNo;

-- La factura debe resolver exactamente un HRC distinto.
SELECT
    COUNT(DISTINCT recepcionLinea.[Document No_]) AS [Cantidad HRC encontrados],
    CASE COUNT(DISTINCT recepcionLinea.[Document No_])
        WHEN 0 THEN N'ERROR: no se encontro HRC'
        WHEN 1 THEN N'OK: se encontro un HRC'
        ELSE N'ERROR: se encontro mas de un HRC'
    END AS [Resultado validacion HRC]
FROM dbo.[FASANI$Purch_ Rcpt_ Line$437dbf0e-84ff-417a-965d-ed2bb9650972] recepcionLinea
INNER JOIN dbo.[FASANI$Purch_ Inv_ Line$437dbf0e-84ff-417a-965d-ed2bb9650972] facturaLinea
    ON recepcionLinea.[Order No_] = facturaLinea.[Order No_]
   AND recepcionLinea.[No_] = facturaLinea.[No_]
   AND recepcionLinea.[Quantity] = facturaLinea.[Quantity]
   AND facturaLinea.[Quantity] <> 0
WHERE facturaLinea.[Document No_] = @DocumentoNo;


/*--------------------------------------------------------------------------------------
    MODIFICACION - FILAS QUE SERIAN AFECTADAS

    DTE AuthNumber y Signature Validation solo afectan los encabezados DTE de FAC y HRC.
    Las tablas del DTE abreviado solo se afectan cuando cambia DTE Invoice.
--------------------------------------------------------------------------------------*/

-- Factura FAC: campos DTE.
SELECT
    [No_],
    [DTE Invoice],
    [DTE AuthNumber],
    [Signature Validation]
FROM dbo.[FASANI$Purch_ Inv_ Header$6961bd3e-336c-4dde-aeee-16842646cf34]
WHERE [No_] = @DocumentoNo;

-- Factura FAC: Vendor Invoice No. recibe el DTE abreviado.
SELECT
    [No_],
    [Buy-from Vendor No_],
    [Order No_],
    [Vendor Invoice No_]
FROM dbo.[FASANI$Purch_ Inv_ Header$437dbf0e-84ff-417a-965d-ed2bb9650972]
WHERE [No_] = @DocumentoNo;

-- Factura FAC: Vendor Invoice Number de IDS Localizacion recibe el DTE abreviado.
SELECT
    [No_],
    [Vendor Invoice Number]
FROM dbo.[FASANI$Purch_ Inv_ Header$c2ec0fd9-a04f-49ff-8054-df8b17008af7]
WHERE [No_] = @DocumentoNo;

-- HRC exacto relacionado por lineas: campos DTE.
SELECT DISTINCT
    dte.[No_],
    dte.[DTE Invoice],
    dte.[DTE AuthNumber],
    dte.[Signature Validation]
FROM dbo.[FASANI$Purch_ Rcpt_ Line$437dbf0e-84ff-417a-965d-ed2bb9650972] recepcionLinea
INNER JOIN dbo.[FASANI$Purch_ Inv_ Line$437dbf0e-84ff-417a-965d-ed2bb9650972] facturaLinea
    ON recepcionLinea.[Order No_] = facturaLinea.[Order No_]
   AND recepcionLinea.[No_] = facturaLinea.[No_]
   AND recepcionLinea.[Quantity] = facturaLinea.[Quantity]
   AND facturaLinea.[Quantity] <> 0
INNER JOIN dbo.[FASANI$Purch_ Inv_ Header$437dbf0e-84ff-417a-965d-ed2bb9650972] factura
    ON facturaLinea.[Document No_] = factura.[No_]
INNER JOIN dbo.[FASANI$Purch_ Rcpt_ Header$6961bd3e-336c-4dde-aeee-16842646cf34] dte
    ON dte.[No_] = recepcionLinea.[Document No_]
WHERE factura.[No_] = @DocumentoNo;

-- HRC exacto relacionado por lineas: FSN Vendor Invoice No. recibe el DTE abreviado.
SELECT DISTINCT
    abreviado.[No_],
    abreviado.[FSN Vendor Invoice No_]
FROM dbo.[FASANI$Purch_ Rcpt_ Line$437dbf0e-84ff-417a-965d-ed2bb9650972] recepcionLinea
INNER JOIN dbo.[FASANI$Purch_ Inv_ Line$437dbf0e-84ff-417a-965d-ed2bb9650972] facturaLinea
    ON recepcionLinea.[Order No_] = facturaLinea.[Order No_]
   AND recepcionLinea.[No_] = facturaLinea.[No_]
   AND recepcionLinea.[Quantity] = facturaLinea.[Quantity]
   AND facturaLinea.[Quantity] <> 0
INNER JOIN dbo.[FASANI$Purch_ Inv_ Header$437dbf0e-84ff-417a-965d-ed2bb9650972] factura
    ON facturaLinea.[Document No_] = factura.[No_]
INNER JOIN dbo.[FASANI$Purch_ Rcpt_ Header$62f6f99a-4d99-497c-af9f-16f62493c460] abreviado
    ON abreviado.[No_] = recepcionLinea.[Document No_]
WHERE factura.[No_] = @DocumentoNo;

-- Movimientos de proveedor.
SELECT
    [Entry No_],
    [Document No_],
    [Document Type],
    [External Document No_]
FROM dbo.[FASANI$Vendor Ledger Entry$437dbf0e-84ff-417a-965d-ed2bb9650972]
WHERE [Document No_] = @DocumentoNo
  AND [Document Type] = 2;

-- Movimientos contables de compras.
SELECT
    [Entry No_],
    [Document No_],
    [Document Type],
    [Source Code],
    [External Document No_]
FROM dbo.[FASANI$G_L Entry$437dbf0e-84ff-417a-965d-ed2bb9650972]
WHERE [Document No_] = @DocumentoNo
  AND [Document Type] = 2
  AND [Source Code] = N'COMPRAS';

-- Documento legal.
SELECT
    [No_],
    [Sub Type],
    [External Document No_]
FROM dbo.[FASANI$Legal Ledger Entry$c2ec0fd9-a04f-49ff-8054-df8b17008af7]
WHERE [No_] = @DocumentoNo
  AND [Sub Type] = N'CCF-C';
