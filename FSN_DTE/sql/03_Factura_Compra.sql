/*
    FSN CORRECTION DTE - HISTORICO FACTURA COMPRA
    Solo lectura: no contiene UPDATE, INSERT ni DELETE.

    Escriba los valores que desea probar. Deje NULL cuando el campo no cambia.
*/

SET NOCOUNT ON;

DECLARE
    @DocumentoNo       NVARCHAR(20) = N'FAC0000051825',
    @DTEInvoiceNuevo   NVARCHAR(31) = NULL,
    @DTEAuthNuevo      NVARCHAR(36) = NULL,
    @SignatureNuevo    NVARCHAR(50) = NULL,
    @DTEAbreviadoNuevo NVARCHAR(35) = NULL;


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

-- Detectar exactamente que campos cambiaron.
SELECT
    dte.[No_],
    dte.[DTE Invoice] AS [DTE Invoice actual],
    @DTEInvoiceNuevo AS [DTE Invoice nuevo],
    CASE
        WHEN @DTEInvoiceNuevo IS NULL THEN N'NO SOLICITADO'
        WHEN ISNULL(dte.[DTE Invoice], N'') = @DTEInvoiceNuevo THEN N'SIN CAMBIO'
        ELSE N'CAMBIA'
    END AS [Estado DTE Invoice],
    dte.[DTE AuthNumber] AS [Codigo Generacion actual],
    @DTEAuthNuevo AS [Codigo Generacion nuevo],
    CASE
        WHEN @DTEAuthNuevo IS NULL THEN N'NO SOLICITADO'
        WHEN ISNULL(dte.[DTE AuthNumber], N'') = @DTEAuthNuevo THEN N'SIN CAMBIO'
        ELSE N'CAMBIA'
    END AS [Estado Codigo Generacion],
    dte.[Signature Validation] AS [Sello Validacion actual],
    @SignatureNuevo AS [Sello Validacion nuevo],
    CASE
        WHEN @SignatureNuevo IS NULL THEN N'NO SOLICITADO'
        WHEN ISNULL(dte.[Signature Validation], N'') = @SignatureNuevo THEN N'SIN CAMBIO'
        ELSE N'CAMBIA'
    END AS [Estado Sello Validacion]
FROM dbo.[FASANI$Purch_ Inv_ Header$6961bd3e-336c-4dde-aeee-16842646cf34] dte
WHERE dte.[No_] = @DocumentoNo;

-- DTE Invoice: no debe existir en otra factura del mismo proveedor y anio.
SELECT TOP (1)
    dte.[No_],
    dte.[DTE Invoice],
    info.[Buy-from Vendor No_],
    info.[Vendor Invoice No_],
    info.[Posting Date]
FROM dbo.[FASANI$Purch_ Inv_ Header$6961bd3e-336c-4dde-aeee-16842646cf34] dte
INNER JOIN dbo.[FASANI$Purch_ Inv_ Header$437dbf0e-84ff-417a-965d-ed2bb9650972] info
    ON info.[No_] = dte.[No_]
INNER JOIN dbo.[FASANI$Purch_ Inv_ Header$437dbf0e-84ff-417a-965d-ed2bb9650972] actual
    ON actual.[No_] = @DocumentoNo
WHERE @DTEInvoiceNuevo IS NOT NULL
  AND dte.[DTE Invoice] = @DTEInvoiceNuevo
  AND info.[Buy-from Vendor No_] = actual.[Buy-from Vendor No_]
  AND YEAR(info.[Posting Date]) = YEAR(actual.[Posting Date])
  AND dte.[No_] <> @DocumentoNo;

-- Codigo de generacion: no debe existir en otra factura.
SELECT TOP (1)
    [No_],
    [DTE AuthNumber]
FROM dbo.[FASANI$Purch_ Inv_ Header$6961bd3e-336c-4dde-aeee-16842646cf34]
WHERE @DTEAuthNuevo IS NOT NULL
  AND [DTE AuthNumber] = @DTEAuthNuevo
  AND [No_] <> @DocumentoNo;

-- Sello de validacion: no debe existir en otra factura.
SELECT TOP (1)
    [No_],
    [Signature Validation]
FROM dbo.[FASANI$Purch_ Inv_ Header$6961bd3e-336c-4dde-aeee-16842646cf34]
WHERE @SignatureNuevo IS NOT NULL
  AND [Signature Validation] = @SignatureNuevo
  AND [No_] <> @DocumentoNo;

-- El Vendor Invoice No. abreviado no debe existir para el mismo proveedor.
SELECT TOP (1)
    candidato.[No_],
    candidato.[Buy-from Vendor No_],
    candidato.[Vendor Invoice No_]
FROM dbo.[FASANI$Purch_ Inv_ Header$437dbf0e-84ff-417a-965d-ed2bb9650972] candidato
INNER JOIN dbo.[FASANI$Purch_ Inv_ Header$437dbf0e-84ff-417a-965d-ed2bb9650972] actual
    ON actual.[No_] = @DocumentoNo
WHERE @DTEAbreviadoNuevo IS NOT NULL
  AND candidato.[Vendor Invoice No_] = @DTEAbreviadoNuevo
  AND candidato.[Buy-from Vendor No_] = actual.[Buy-from Vendor No_]
  AND candidato.[No_] <> @DocumentoNo;

-- Obtener el pedido de la factura y todas las recepciones HRC relacionadas.
SELECT
    factura.[No_] AS [Factura No_],
    factura.[Order No_],
    recepcion.[No_] AS [Recepcion No_],
    recepcion.[Posting Date]
FROM dbo.[FASANI$Purch_ Inv_ Header$437dbf0e-84ff-417a-965d-ed2bb9650972] factura
LEFT JOIN dbo.[FASANI$Purch_ Rcpt_ Header$437dbf0e-84ff-417a-965d-ed2bb9650972] recepcion
    ON recepcion.[Order No_] = factura.[Order No_]
WHERE factura.[No_] = @DocumentoNo;


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

-- Recepciones HRC relacionadas: campos DTE.
SELECT
    dte.[No_],
    dte.[DTE Invoice],
    dte.[DTE AuthNumber],
    dte.[Signature Validation]
FROM dbo.[FASANI$Purch_ Rcpt_ Header$6961bd3e-336c-4dde-aeee-16842646cf34] dte
INNER JOIN dbo.[FASANI$Purch_ Rcpt_ Header$437dbf0e-84ff-417a-965d-ed2bb9650972] recepcion
    ON recepcion.[No_] = dte.[No_]
INNER JOIN dbo.[FASANI$Purch_ Inv_ Header$437dbf0e-84ff-417a-965d-ed2bb9650972] factura
    ON factura.[Order No_] = recepcion.[Order No_]
WHERE factura.[No_] = @DocumentoNo;

-- Recepciones HRC relacionadas: FSN Vendor Invoice No. recibe el DTE abreviado.
SELECT
    abreviado.[No_],
    abreviado.[FSN Vendor Invoice No_]
FROM dbo.[FASANI$Purch_ Rcpt_ Header$62f6f99a-4d99-497c-af9f-16f62493c460] abreviado
INNER JOIN dbo.[FASANI$Purch_ Rcpt_ Header$437dbf0e-84ff-417a-965d-ed2bb9650972] recepcion
    ON recepcion.[No_] = abreviado.[No_]
INNER JOIN dbo.[FASANI$Purch_ Inv_ Header$437dbf0e-84ff-417a-965d-ed2bb9650972] factura
    ON factura.[Order No_] = recepcion.[Order No_]
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
    [Entry No_],
    [No_],
    [Sub Type],
    [External Document No_]
FROM dbo.[FASANI$Legal Ledger Entry$c2ec0fd9-a04f-49ff-8054-df8b17008af7]
WHERE [No_] = @DocumentoNo
  AND [Sub Type] = N'CCF-C';

