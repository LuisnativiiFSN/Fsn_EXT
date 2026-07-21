report 50045 "FSN KardexReport"
{
    // WVILLALTA15FEB18 Cambio de descripcion en ajustes de auditoria
    // FSNFRODRIGUEZ21NOV2018 se agrego para concideracion el tipo de movimiento ensamblado (entrada y salida)
    // FRODRIGUEZ16FEB2019                       -Agregacion de filtro tienda para completar la llave correspondiente a la tabla transaction Header
    ApplicationArea = All;
    UsageCategory = Administration;
    DefaultLayout = RDLC;
    Caption = 'FSN Kardex Report';
    RDLCLayout = './src/Report/Layout/KardexReport.rdl';
    PreviewMode = PrintLayout;


    dataset
    {
        dataitem(KardexRep; "FSN KardexRep")
        {
            DataItemTableView = SORTING(Clave, "Posting Date", Correlativo)
                                ORDER(Ascending);
            column(UnitofMeasureCode_Barcodes; KardexRep."Unit of Measure Code")
            {
            }
            column(BarcodeNo_Barcodes; KardexRep."Barcode No.")
            {
            }
            column(Description_Barcodes; KardexRep.Description)
            {
            }
            column(Company_Name; COMPANYNAME)
            {
            }
            column(Company_Former_Name; CompanyFormerName)
            {
            }
            column(Company_NIT; "CompanyVATRegistrationNo.")
            {
            }
            column(Company_NRC; CompanyNRC)
            {
            }
            column(Store_Name; StoreName)
            {
            }
            column(SalesAmountActual_ItemLedgerEntry; KardexRep."Sales Amount (Actual)")
            {
            }
            column(ItemNo_ItemLedgerEntry; KardexRep."Item No.")
            {
            }
            column(EntryNo_ItemLedgerEntry; KardexRep."Entry No.")
            {
            }
            column(ExternalDocumentNo_ItemLedgerEntry; KardexRep."External Document No.")
            {
            }
            column(PostingDate_ItemLedgerEntry; KardexRep."Posting Date")
            {
            }
            column(EntryType_ItemLedgerEntry; KardexRep."Entry Type")
            {
            }
            column(DocumentNo_ItemLedgerEntry; KardexRep."Document No.")
            {
            }
            column(Quantity_ItemLedgerEntry; KardexRep.Quantity)
            {
            }
            column(CostAmountActual_ItemLedgerEntry; KardexRep."Cost Amount (Actual)")
            {
            }
            column(PurchaseAmountActual_ItemLedgerEntry; KardexRep."Purchase Amount (Actual)")
            {
            }
            column(LocationCode_ItemLedgerEntry; KardexRep."Location Code")
            {
            }
            column(CountryRegionCode_ItemLedgerEntry; KardexRep."Country/Region Code")
            {
            }
            column(CostAmountExpected_ItemLedgerEntry; KardexRep."Cost Amount (Expected)")
            {
            }
            column(DocumentType_ItemLedgerEntry; KardexRep."Document Type")
            {
            }
            column(Item_Sales_Price; ItemSalesPrice)
            {
            }
            column(Starting_Invoiced_Qty; StartingInvoicedQty)
            {
            }
            column(Starting_Invoiced_Value; StartingInvoicedValue)
            {
            }
            column(EndingInvoicedValue; StartingInvoicedValue + IncreaseInvoicedValue - DecreaseInvoicedValue)
            {
            }
            column(EndingInvoicedQty; StartingInvoicedQty + IncreaseInvoicedQty - DecreaseInvoicedQty)
            {
            }
            column(Starting_Date; StartingDate)
            {
            }
            column(Ending_Date; EndingDate)
            {
            }
            column(Locat; Locat)
            {
            }
            column(Name_Vendor; KardexRep.Name)
            {
            }
            column(ItemUnitCost; KardexRep.ItemUnitCost)
            {
            }
            column(KdxTipo; KardexRep.Tipo)
            {
            }
            column(KdxTransaccion; KardexRep.Transaccion)
            {
            }
            column(KdxFecha; KardexRep.Fecha)
            {
            }
            column(KdxDocumento; KardexRep.Documento)
            {
            }
            column(KdxCosto; KardexRep.Costo)
            {
            }
            column(KdxProveedor; KardexRep.Proveedor)
            {
            }
            column(KdxCountry; KardexRep.Nacional)
            {
            }
            column(KdxQtyEnt; KardexRep.QtyEnt)
            {
            }
            column(KdxQtySal; KardexRep.QtySal)
            {
            }
            column(KdxQtyBal; KardexRep.QtyBal)
            {
            }
            column(KdxAmtEnt; KardexRep.AmtEnt)
            {
            }
            column(KdxAmtSal; KardexRep.AmtSal)
            {
            }
            column(KdLote; KardexRep."Lote No.")
            {
            }
            column(KdFechaVencimiento; KardexRep."Fecha Vencimiento")
            {
            }
            column(KdxAmtBal; KardexRep.AmtBal)
            {
            }

            trigger OnAfterGetRecord()
            begin
                IF NOT (("Entry Type" = "Entry Type"::Purchase) OR
                ("Entry Type" = "Entry Type"::Sale) OR
                ("Entry Type" = "Entry Type"::Transfer) OR
                ("Entry Type" = "Entry Type"::"Negative Adjmt.") OR
                ("Entry Type" = "Entry Type"::"Positive Adjmt.") OR
                ("Entry Type" = "Entry Type"::"Assembly Output") OR //FSNFRODRIGUEZ21NOV2018 INICIO
                ("Entry Type" = "Entry Type"::"Assembly Consumption")) THEN //FSNFRODRIGUEZ21NOV2018 FIN
                    CurrReport.SKIP;

                StartingInvoicedValue := 0;
                StartingInvoicedQty := 0;

                ValueEntry.RESET;
                ValueEntry.SETRANGE("Item No.", KardexRep."Item No.");

                IF StartingDate > 0D THEN BEGIN
                    ValueEntry.SETRANGE("Posting Date", 0D, CALCDATE('<-1D>', StartingDate));
                    ValueEntry.CALCSUMS("Item Ledger Entry Quantity", "Cost Amount (Actual)", "Cost Amount (Expected)", "Invoiced Quantity");
                    AssignAmounts(ValueEntry, StartingInvoicedValue, StartingInvoicedQty, 1);
                END;

                ValueEntry.SETRANGE("Posting Date", StartingDate, EndingDate);
                ValueEntry.SETFILTER(
                  "Item Ledger Entry Type", '%1',
                  ValueEntry."Item Ledger Entry Type"::Purchase);
                ValueEntry.CALCSUMS("Item Ledger Entry Quantity", "Cost Amount (Actual)", "Cost Amount (Expected)", "Invoiced Quantity");
                AssignAmounts(ValueEntry, IncreaseInvoicedValue, IncreaseInvoicedQty, 1);

                ValueEntry.SETRANGE("Posting Date", StartingDate, EndingDate);
                ValueEntry.SETFILTER(
                  "Item Ledger Entry Type", '%1',
                  ValueEntry."Item Ledger Entry Type"::Sale);
                ValueEntry.CALCSUMS("Item Ledger Entry Quantity", "Cost Amount (Actual)", "Cost Amount (Expected)", "Invoiced Quantity");
                AssignAmounts(ValueEntry, DecreaseInvoicedValue, DecreaseInvoicedQty, -1);

                //ValueEntry.SETRANGE("Posting Date",StartingDate,EndingDate);
                //ValueEntry.SETFILTER(
                //  "Item Ledger Entry Type",'%1',
                //  ValueEntry."Item Ledger Entry Type"::"Assembly Output");
                //ValueEntry.CALCSUMS("Item Ledger Entry Quantity","Cost Amount (Actual)","Cost Amount (Expected)","Invoiced Quantity");
                //AssignAmounts(ValueEntry,DecreaseInvoicedValue,DecreaseInvoicedQty,-1);


                xSalesPrice.RESET;
                xSalesPrice.SETRANGE("Item No.", KardexRep."Item No.");
                IF xSalesPrice.FINDFIRST THEN
                    ItemSalesPrice := xSalesPrice."Unit Price";
            end;

            trigger OnPreDataItem()
            begin
                CurrReport.CREATETOTALS(StartingInvoicedQty);
                CurrReport.CREATETOTALS(StartingInvoicedValue);

                SETRANGE(Clave, xTimeStamp);
            end;
        }
    }

    requestpage
    {

        layout
        {
            area(content)
            {
                field(StartingDate; StartingDate)
                {
                    Caption = 'Desde';
                }
                field(EndingDate; EndingDate)
                {
                    Caption = 'Hasta';
                }
                field(Locat; Locat)
                {
                    Caption = 'Sucursal';
                    Lookup = true;
                    LookupPageID = "LSC Store List";

                    trigger OnLookup(var Text: Text): Boolean
                    begin
                        lStore."No." := Locat;
                        IF PAGE.RUNMODAL(99001469, lStore) = ACTION::LookupOK THEN
                            Locat := lStore."No.";
                    end;
                }
                field(Barcode; Barcode)
                {
                    Caption = 'Producto';
                    Lookup = true;
                    LookupPageID = "Item List";

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        xList: Page "Item List";
                    begin
                        lItems."No." := Barcode;
                        IF PAGE.RUNMODAL(31, lItems) = ACTION::LookupOK THEN
                            Barcode := lItems."No.";
                    end;
                }
            }
        }

        actions
        {
        }
    }

    labels
    {
    }

    trigger OnPostReport()
    begin
        // Limpiar la tabla temporal

        CLEAR(xKardexRep);
        xKardexRep.SETRANGE(Clave, xTimeStamp);
        IF xKardexRep.FIND('-') THEN
            xKardexRep.DELETEALL();
    end;

    trigger OnPreReport()
    var
        xSeries: Record "No. Series Line";
        NumDoc: Text[35];
        nCorr: Integer;
        nCosto: Decimal;
        nExistencia: Decimal;
        nCostoIni: Decimal;
        nExistenciaIni: Decimal;
        nCantEnt: Decimal;
        nCantSal: Decimal;
        EntryStatus: Record "LSC Trans. Sales Entry Status";
        TransacDTE: Record "FSN DTE Transaction Header";
        TransacHeader: Record "LSC Transaction Header";
        PurchRCpHeader: Record "Purch. Rcpt. Header";
        ItemLed: Record "Item Ledger Entry";
    begin

        IF (StartingDate = 0D) AND (EndingDate = 0D) THEN
            EndingDate := WORKDATE;

        //CompanyInfo.RESET;
        //CompanyInfo.SETRANGE("Name 2", COMPANYNAME);
        IF CompanyInfo.get() THEN BEGIN
            CompanyFormerName := CompanyInfo.Name;
            "CompanyVATRegistrationNo." := CompanyInfo."Federal ID No.";
            CompanyNRC := CompanyInfo."FSN NRC";
        END;

        Location := Locat;

        RetailUser.RESET;
        RetailUser.SETRANGE(ID, USERID);
        IF RetailUser.FINDFIRST THEN BEGIN
            IF NOT ((RetailUser."Location Code" = Location) OR (RetailUser."Location Code" = '')) THEN
                ERROR('El usuario actual no esta asociado a esta tienda');
        END;

        Store.RESET;
        Store.SETRANGE(Store."Location Code", Location);
        IF Store.FINDFIRST THEN
            StoreName := Store.Name;

        xTimeStamp := FORMAT(WORKDATE, 8, '<Year><Month,2><Day,2>') + FORMAT(TIME, 10, '<Hours24><Minutes,2><Seconds,2><Second dec>');

        // Llenar la tabla KardexRep con Datos de Item Ledger Entry (Ajustes +/- y Compras)
        CLEAR(xItemLedger);
        xItemLedger.SETRANGE("Item No.", Barcode);
        xItemLedger.SETRANGE("Location Code", Location);
        //xItemLedger.SetRange("Global Dimension 2 Code", '01');
        xItemLedger.SETFILTER("Posting Date", '>=%1&<=%2', StartingDate, EndingDate);

        //FSNFRODRIGUEZ21NOV2018 INICIO
        //xItemLedger.SETFILTER("Entry Type", '=%1|=%2|=%3|=%4|=%5', xItemLedger."Entry Type"::Purchase, xItemLedger."Entry Type"::"Positive Adjmt.", xItemLedger."Entry Type"::"Negative Adjmt.", xItemLedger."Entry Type"::Transfer);
        //xItemLedger.SETFILTER("Entry Type", '<>%1', xItemLedger."Entry Type"::Sale);
        //FSNFRODRIGUEZ21NOV2018 FIN

        IF xItemLedger.FIND('-') THEN
            REPEAT
                xItemLedger.CALCFIELDS("Sales Amount (Actual)", "Cost Amount (Actual)", "Purchase Amount (Actual)", "Cost Amount (Expected)");
                // Insertar los registros en la tabla del reporte
                xKardexRep.INIT();
                xKardexRep.Clave := xTimeStamp;
                xItem.GET(xItemLedger."Item No.");
                xKardexRep.ItemUnitCost := xItem."Unit Cost";
                xKardexRep."Unit of Measure Code" := xItem."Base Unit of Measure";
                xBarcodes.SETRANGE("Item No.", xItemLedger."Item No.");
                xBarcodes.SETRANGE("Unit of Measure Code", xItem."Base Unit of Measure");
                IF xBarcodes.FIND('-') THEN BEGIN
                    xKardexRep."Barcode No." := xBarcodes."Barcode No.";
                    xKardexRep.Description := xBarcodes.Description;
                END ELSE BEGIN
                    xKardexRep."Barcode No." := xItem."FSN Barcode No.";
                    xKardexRep.Description := xItem.Description;
                END;
                xKardexRep."Sales Amount (Actual)" := xItemLedger."Sales Amount (Actual)";
                xKardexRep."Item No." := xItemLedger."Item No.";
                xKardexRep."Entry No." := xItemLedger."Entry No.";
                xKardexRep."Posting Date" := xItemLedger."Posting Date";
                xKardexRep."Entry Type" := xItemLedger."Entry Type";
                if xItemLedger."Entry Type" = xItemLedger."Entry Type"::Sale then begin
                    TransacHeader.Reset();
                    TransacHeader.SetCurrentKey("Receipt No.");
                    if STRPOS(xItemLedger."External Document No.", 'DTE') > 0 then begin
                        xKardexRep."Document No." := xItemLedger."External Document No.";
                    end else begin
                        TransacHeader.SetRange("Receipt No.", OnReadReceip(xItemLedger."External Document No."));
                        if TransacHeader.FindSet() then begin
                            TransacDTE.Reset();
                            TransacDTE.SetRange("Transaction No.", TransacHeader."Transaction No.");
                            TransacDTE.SetRange("Store No.", TransacHeader."Store No.");
                            TransacDTE.SetRange("POS Terminal No.", TransacHeader."POS Terminal No.");
                            if TransacDTE.FindSet() then
                                xKardexRep."Document No." := TransacDTE."DTE Invoice"
                            else
                                xKardexRep."Document No." := TransacHeader."FSN Correlative";
                        end else
                            xKardexRep."Document No." := '';
                    end;
                end else
                    if xItemLedger."Entry Type" = xItemLedger."Entry Type"::Purchase then begin
                        PurchRCpHeader.Reset();
                        PurchRCpHeader.SetRange("No.", xItemLedger."Document No.");
                        PurchRCpHeader.SetRange("Pay-to Vendor No.", xItemLedger."Source No.");
                        if PurchRCpHeader.FindSet() then begin
                            if PurchRCpHeader."DTE Invoice" <> '' then
                                xKardexRep."Document No." := PurchRCpHeader."DTE Invoice"
                            else begin
                                xKardexRep."Document No." := PurchaseVendorInvNo(PurchRCpHeader."No.");
                                if xKardexRep."Document No." = '' then
                                    xKardexRep."Document No." := xItemLedger."Document No.";
                            end;
                        end else
                            xKardexRep."Document No." := xItemLedger."Document No.";
                    end else
                        xKardexRep."Document No." := xItemLedger."External Document No.";

                xKardexRep."External Document No." := xItemLedger."Document No.";
                xKardexRep."Document Type" := xItemLedger."Document Type";
                xKardexRep.Quantity := xItemLedger.Quantity;
                xKardexRep."Lote No." := xItemLedger."Lot No.";
                xKardexRep."Fecha Vencimiento" := xItemLedger."Expiration Date";
                xKardexRep."Cost Amount (Actual)" := xItemLedger."Cost Amount (Actual)";
                xKardexRep."Purchase Amount (Actual)" := xItemLedger."Purchase Amount (Actual)";
                xKardexRep."Location Code" := xItemLedger."Location Code";
                xKardexRep."Country/Region Code" := xItemLedger."Country/Region Code";
                xKardexRep."Cost Amount (Expected)" := xItemLedger."Cost Amount (Expected)";
                IF xVendor.GET(xItemLedger."Source No.") THEN
                    xKardexRep.Name := xVendor.Name;

                xKardexRep.INSERT();
            UNTIL xItemLedger.NEXT <= 0;

        // Insertar las ventas no posteadas en Sales Entry Status
        CLEAR(xTrSales);
        xTrSales.SETRANGE("Item No.", Barcode);
        xTrSales.SETRANGE("Store No.", Location);
        xTrSales.SETFILTER(Date, '>=%1&<=%2', StartingDate, EndingDate);
        IF xTrSales.FIND('-') THEN
            REPEAT
                ItemLed.Reset();
                ItemLed.SetRange("Document No.", xTrSales."Receipt No.");
                ItemLed.SetRange("Item No.", xTrSales."Item No.");
                ItemLed.SetRange("Location Code", xTrSales."Store No.");
                if not ItemLed.FindFirst() then begin
                    EntryStatus.Reset();//28981
                    EntryStatus.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
                    EntryStatus.SetRange("Store No.", xTrSales."Store No.");
                    EntryStatus.SetRange(EntryStatus."POS Terminal No.", xTrSales."POS Terminal No.");
                    EntryStatus.SetRange(EntryStatus."Transaction No.", xTrSales."Transaction No.");
                    EntryStatus.SetRange(EntryStatus.Status, EntryStatus.Status::Posted);
                    if not EntryStatus.FindFirst() then begin
                        xKardexRep.INIT;
                        xKardexRep.Clave := xTimeStamp;
                        xItem.GET(xTrSales."Item No.");
                        xKardexRep.ItemUnitCost := xItem."Unit Cost";
                        xKardexRep."Unit of Measure Code" := xItem."Base Unit of Measure";
                        xBarcodes.SETRANGE("Item No.", xItemLedger."Item No.");
                        xBarcodes.SETRANGE("Unit of Measure Code", xItem."Base Unit of Measure");
                        IF xBarcodes.FIND('-') THEN BEGIN
                            xKardexRep."Barcode No." := xBarcodes."Barcode No.";
                            xKardexRep.Description := xBarcodes.Description;
                        END ELSE BEGIN
                            xKardexRep."Barcode No." := xItem."FSN Barcode No.";
                            xKardexRep.Description := xItem.Description;
                        END;
                        xKardexRep."Sales Amount (Actual)" := xTrSales."Net Amount";
                        xKardexRep."Item No." := xTrSales."Item No.";

                        IF xTrSales."Transaction No." < 10 THEN
                            xKardexRep."Entry No." := (1000000 * xTrSales."Transaction No.") + ((xTrSales."Line No." / 100) DIV 1)
                        ELSE
                            IF xTrSales."Transaction No." < 100 THEN
                                xKardexRep."Entry No." := (100000 * xTrSales."Transaction No.") + ((xTrSales."Line No." / 100) DIV 1)
                            ELSE
                                IF xTrSales."Transaction No." < 1000 THEN
                                    xKardexRep."Entry No." := (10000 * xTrSales."Transaction No.") + ((xTrSales."Line No." / 100) DIV 1)
                                ELSE
                                    IF xTrSales."Transaction No." < 10000 THEN
                                        xKardexRep."Entry No." := (1000 * xTrSales."Transaction No.") + ((xTrSales."Line No." / 100) DIV 1)
                                    ELSE
                                        IF xTrSales."Transaction No." < 100000 THEN
                                            xKardexRep."Entry No." := (100 * xTrSales."Transaction No.") + ((xTrSales."Line No." / 100) DIV 1)
                                        ELSE
                                            xKardexRep."Entry No." := (10 * xTrSales."Transaction No.") + ((xTrSales."Line No." / 100) DIV 1);
                        xTrHeader.SETRANGE("Store No.", xTrSales."Store No.");           //FRODRIGUEZ16FEB2019
                        xTrHeader.SETRANGE("Transaction No.", xTrSales."Transaction No.");
                        xTrHeader.SETRANGE("POS Terminal No.", xTrSales."POS Terminal No.");
                        IF xTrHeader.FIND('-') THEN BEGIN
                            NumDoc := xTrHeader."FSN NCF";
                            IF (COPYSTR(xTrHeader."FSN No. Serie NCF", 1, 3) = 'FAC') OR (COPYSTR(xTrHeader."FSN No. Serie NCF", 1, 3) = 'CRE') THEN BEGIN
                                // Encontrar el numero de serie
                                xSeries.RESET;
                                xSeries.SETRANGE("Series Code", xTrHeader."FSN No. Serie NCF");
                                xSeries.SETFILTER("Starting No.", '<=%1', NumDoc);
                                xSeries.SETFILTER("Ending No.", '>=%1', NumDoc);
                                IF xSeries.FIND('-') THEN
                                    NumDoc := xSeries."FSN Autorization" + NumDoc;

                                IF COPYSTR(xTrHeader."FSN No. Serie NCF", 1, 3) = 'FAC' THEN
                                    NumDoc := 'FC' + NumDoc
                                ELSE
                                    NumDoc := 'CF' + NumDoc;
                            END;
                            xKardexRep."External Document No." := NumDoc;
                        END ELSE BEGIN
                            xKardexRep."External Document No." := xTrSales."Receipt No.";
                        END;
                        xKardexRep."Posting Date" := xTrSales.Date;
                        xKardexRep."Entry Type" := xKardexRep."Entry Type"::Sale;
                        TransacDTE.Reset();
                        TransacDTE.SetRange("Transaction No.", xTrHeader."Transaction No.");
                        TransacDTE.SetRange("Store No.", xTrHeader."Store No.");
                        TransacDTE.SetRange("POS Terminal No.", xTrHeader."POS Terminal No.");
                        if TransacDTE.FindSet() then
                            xKardexRep."Document No." := TransacDTE."DTE Invoice"
                        else
                            xKardexRep."Document No." := xTrHeader."FSN Correlative";

                        if xKardexRep."Document No." = '' then
                            xKardexRep."Document No." := xKardexRep."External Document No.";
                        xKardexRep.Quantity := xTrSales.Quantity;
                        xKardexRep."Lote No." := xTrSales."Lot No.";
                        xKardexRep."Fecha Vencimiento" := xTrSales."Expiration Date";
                        xKardexRep."Cost Amount (Actual)" := xTrSales."Cost Amount";
                        xKardexRep."Purchase Amount (Actual)" := 0;
                        xKardexRep."Location Code" := xTrSales."Store No.";
                        xKardexRep."Cost Amount (Expected)" := 0;
                        xKardexRep.INSERT();
                    end;
                end;
            UNTIL xTrSales.NEXT <= 0;

        xTimeStamp := xTimeStamp;
        nCorr := 1;

        ValueEntry.RESET;
        ValueEntry.SETRANGE("Item No.", Barcode);
        ValueEntry.SETRANGE("Location Code", Location);

        IF StartingDate > 0D THEN BEGIN
            ValueEntry.SETRANGE("Posting Date", 0D, CALCDATE('<-1D>', StartingDate));
            ValueEntry.CALCSUMS("Item Ledger Entry Quantity", "Cost Amount (Actual)", "Cost Amount (Expected)", "Invoiced Quantity");
        END;

        // Formula a usar:
        // Costo = (ExistenciaAnterior * CostoAnterior) + (UnidadesEntrada * CostoEntrada) / (ExistenciaAnterior + UnidadesEntrada)
        nExistencia := ValueEntry."Invoiced Quantity";
        nCosto := ValueEntry."Cost Amount (Actual)";
        IF nExistencia <> 0 THEN nCosto := nCosto / nExistencia ELSE nCosto := 0;
        IF nCosto = 0 THEN BEGIN
            // Si no hay costo Inicial, usar el costo del Articulo en la Tabla de Productos
            IF xItem.GET(Barcode) THEN nCosto := ROUND(xItem."Unit Cost", 0.01, '=');
        END;
        nCostoIni := nCosto;
        nExistenciaIni := nExistencia;

        // Generando el reporte en la tabla
        xKardexRep.RESET;
        xKardexRep.SETRANGE(Clave, xTimeStamp);
        //xKardexRep.SETCURRENTKEY(Clave, "Posting Date", "Entry Type", "External Document No.");
        xKardexRep.SETCURRENTKEY(Clave, "Posting Date", "Entry No.");
        IF xKardexRep.FINDFIRST() THEN
            REPEAT
                nCorr += 1;
                xKardexRep.Correlativo := nCorr;
                nCantEnt := 0;
                nCantSal := 0;
                CASE xKardexRep."Entry Type" OF
                    xKardexRep."Entry Type"::Purchase:
                        BEGIN
                            IF xKardexRep.Quantity > 0 THEN BEGIN
                                IF (nExistencia + xKardexRep.Quantity) <> 0 THEN
                                    nCosto := ROUND(((nExistencia * nCosto) + (xKardexRep.Quantity * (xKardexRep."Cost Amount (Actual)" / xKardexRep.Quantity))) / (nExistencia + xKardexRep.Quantity), 0.01, '=');
                                nCantEnt := xKardexRep.Quantity;
                                xKardexRep.Tipo := 'Compra';
                            END ELSE BEGIN
                                nCantSal := ABS(xKardexRep.Quantity);
                                xKardexRep.Tipo := 'Dev. Compra';
                            END;
                        END;
                    xKardexRep."Entry Type"::"Positive Adjmt.":
                        BEGIN
                            IF xKardexRep.Quantity > 0 THEN BEGIN
                                IF (nExistencia + xKardexRep.Quantity) <> 0 THEN
                                    nCosto := ROUND(((nExistencia * nCosto) + (xKardexRep.Quantity * (xKardexRep."Cost Amount (Actual)" / xKardexRep.Quantity))) / (nExistencia + xKardexRep.Quantity), 0.01, '=');
                                nCantEnt := ABS(xKardexRep.Quantity);
                                xKardexRep.Tipo := 'Ent. Transf. A.';      //WVILLALTA15FEB18-+
                            END ELSE BEGIN
                                nCantSal := ABS(xKardexRep.Quantity);
                                xKardexRep.Tipo := 'Sal. Transf. A.';      //WVILLALTA15FEB18-+
                            END;
                        END;
                    xKardexRep."Entry Type"::"Negative Adjmt.":
                        BEGIN
                            if xKardexRep.Quantity < 0 then begin
                                nCantSal := ABS(xKardexRep.Quantity);
                                xKardexRep.Tipo := 'Sal. Transf. A.';      //WVILLALTA15FEB18-+
                            end else begin
                                //nCosto := ROUND(((nExistencia * nCosto) + (xKardexRep.Quantity * (xKardexRep."Cost Amount (Actual)" / xKardexRep.Quantity))) / (nExistencia + xKardexRep.Quantity), 0.01, '=');
                                nCantEnt := ABS(xKardexRep.Quantity);
                                xKardexRep.Tipo := 'Ent. Transf. A.';
                            end;
                        END;
                    xKardexRep."Entry Type"::Transfer:
                        IF xKardexRep.Quantity < 0 THEN BEGIN
                            nCantSal := ABS(xKardexRep.Quantity);
                            xKardexRep.Tipo := 'Sal. Transf.';
                        END ELSE BEGIN
                            nCantEnt := xKardexRep.Quantity;
                            xKardexRep.Tipo := 'Ent. Transf.';
                        END;
                    xKardexRep."Entry Type"::Sale:
                        BEGIN
                            IF xKardexRep.Quantity > 0 THEN BEGIN
                                xKardexRep.Tipo := 'Dev. Vta.';
                                nCantEnt := xKardexRep.Quantity;
                            END ELSE BEGIN
                                xKardexRep.Tipo := 'Venta';
                                nCantSal := ABS(xKardexRep.Quantity);
                            END;
                        END;
                    //FSNFRODRIGUEZ21NOV2018 INICIO
                    xKardexRep."Entry Type"::"Assembly Output":
                        BEGIN
                            nCantEnt := ABS(xKardexRep.Quantity);
                            xKardexRep.Tipo := 'Sal. Ensamblado';
                        END;
                    xKardexRep."Entry Type"::"Assembly Consumption":
                        BEGIN
                            nCantSal := ABS(xKardexRep.Quantity);
                            xKardexRep.Tipo := 'Consumo Ensamblado';
                        END;
                    //FSNFRODRIGUEZ21NOV2018 FIN


                    ELSE BEGIN
                    END;
                END;
                nExistencia := nExistencia + nCantEnt - nCantSal;
                xKardexRep.Costo := nCosto;
                xKardexRep.QtyEnt := nCantEnt;
                xKardexRep.QtySal := nCantSal;
                xKardexRep.QtyBal := nExistencia;
                IF ABS(nCantEnt * nCosto) > 999999999999999.0 THEN BEGIN
                    xKardexRep.AmtEnt := 999999999999999.99;
                    xKardexRep.AmtSal := 999999999999999.99;
                    xKardexRep.AmtBal := 999999999999999.99;
                END ELSE BEGIN
                    xKardexRep.AmtEnt := nCantEnt * nCosto;
                    xKardexRep.AmtSal := nCantSal * nCosto;
                    xKardexRep.AmtBal := nExistencia * nCosto;
                END;

                xKardexRep.Transaccion := xKardexRep."Entry No.";
                xKardexRep.Fecha := xKardexRep."Posting Date";
                xKardexRep.Documento := xKardexRep."Document No.";
                xKardexRep.Proveedor := xKardexRep.Name;
                xKardexRep.Nacional := xKardexRep."Country/Region Code";
                xKardexRep.MODIFY;
            UNTIL xKardexRep.NEXT <= 0;
        COMMIT;

        xItem.RESET;
        xItem.GET(Barcode);
        xSalesPrice.RESET;
        xSalesPrice.SETRANGE("Item No.", xItem."No.");
        IF xSalesPrice.FINDFIRST THEN
            ItemSalesPrice := xSalesPrice."Unit Price";

        // Insertando valores Iniciales
        xKardexRep.INIT;
        xKardexRep.Clave := xTimeStamp;
        xKardexRep."Posting Date" := CALCDATE('<-1D>', StartingDate);
        xKardexRep."Entry Type" := xKardexRep."Entry Type"::Purchase;
        xKardexRep."External Document No." := '1';
        xKardexRep."Item No." := xItem."No.";
        xKardexRep.Description := xItem.Description;
        xKardexRep."Barcode No." := xItem."FSN Barcode No.";
        xKardexRep."Unit of Measure Code" := xItem."Base Unit of Measure";
        xKardexRep.SalesPrice := ItemSalesPrice;
        xKardexRep.Tipo := 'SI';
        xKardexRep.Correlativo := 1;
        xKardexRep.Costo := nCostoIni;
        xKardexRep.QtyBal := nExistenciaIni;
        IF ABS(nExistenciaIni * nCostoIni) > 999999999999999.0 THEN
            xKardexRep.AmtBal := 999999999999999.99
        ELSE
            xKardexRep.AmtBal := nExistenciaIni * nCostoIni;
        xKardexRep.INSERT;
    end;

    var
        CompanyFormerName: Text[50];
        "CompanyVATRegistrationNo.": Text[20];
        CompanyNRC: Text[30];
        StoreName: Text[30];
        ItemSalesPrice: Decimal;
        Store: Record "LSC Store";
        StartingDate: Date;
        EndingDate: Date;
        Barcode: Code[20];
        ValueEntry: Record "Value Entry";
        StartingInvoicedValue: Decimal;
        StartingInvoicedQty: Decimal;
        IncreaseInvoicedValue: Decimal;
        IncreaseInvoicedQty: Decimal;
        DecreaseInvoicedValue: Decimal;
        DecreaseInvoicedQty: Decimal;
        IsEmptyLine: Boolean;
        CompanyInfo: Record "Company Information";
        xSalesPrice: Record "Sales Price";
        RetailUser: Record "LSC Retail User";
        Locat: Code[10];
        ItemLed: Record "Item Ledger Entry";
        Location: Code[20];
        xItemLedger: Record "Item Ledger Entry";
        xTimeStamp: Code[30];
        xKardexRep: Record "FSN KardexRep";
        xItem: Record Item;
        xBarcodes: Record "LSC Barcodes";
        xVendor: Record "Vendor";
        xTrSales: Record "LSC Trans. Sales Entry";
        xTrHeader: Record "LSC Transaction Header";
        lItems: Record Item;
        lStore: Record "LSC Store";
        yItemNo: Code[20];
        yDescripcion: Text[50];
        yBarra: Text[20];
        yUnitario: Decimal;

    local procedure AssignAmounts(ValueEntry: Record "Value Entry"; var InvoicedValue: Decimal; var InvoicedQty: Decimal; Sign: Decimal)
    begin
        InvoicedValue += ValueEntry."Cost Amount (Actual)" * Sign;
        InvoicedQty += ValueEntry."Invoiced Quantity" * Sign;
    end;

    procedure OnReadReceip(DocNo: Code[50]): Code[20]
    var
        TransactionHeader: Record "LSC Transaction Header";
        StoreNo: Code[10];
        PosNo: Code[10];
        TransNo: Integer;
        Recibo: Code[20];
    begin
        ExplodeDocNo(DocNo, StoreNo, PosNo, TransNo);
        if not TransactionHeader.Get(StoreNo, PosNo, TransNo) then
            exit(DocNo);
        if (TransactionHeader."Legal Serie" = '') and (TransactionHeader."Legal Serie" <> '') then
            Recibo := TransactionHeader."Legal Serie" + TransactionHeader."Legal Serie";

        if (TransactionHeader."Legal Serie" <> '') and (TransactionHeader."Legal Serie" <> '') then
            Recibo := TransactionHeader."Legal Serie" + '-' + TransactionHeader."Legal Serie";

        if (TransactionHeader."Legal Serie" = '') and (TransactionHeader."Legal Serie" = '') then
            Recibo := TransactionHeader."Receipt No.";
        exit(Recibo);
    end;


    procedure ExplodeDocNo(DocNo: Code[20]; VAR StoreNo: Code[10]; VAR PosNo: Code[10]; VAR TransNo: Integer)
    var
        Position: Integer;
        cu: Codeunit "LSC Statement-Post";
        ta: Record "LSC Statement";
    begin
        StoreNo := '';
        PosNo := '';
        TransNo := 0;

        Position := STRPOS(DocNo, '-');
        if Position < 2 then exit;
        StoreNo := CopyStr(DocNo, 1, Position - 1);
        DocNo := COPYSTR(DocNo, Position + 1);

        Position := STRPOS(DocNo, '-');
        if Position < 2 then exit;
        PosNo := CopyStr(DocNo, 1, Position - 1);

        DocNo := COPYSTR(DocNo, Position + 1);

        if not EVALUATE(TransNo, DocNo) then TransNo := 0;
        exit;
    end;

    procedure PurchaseVendorInvNo(FSNVendorInvNo: Code[35]): Code[35]
    var
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
    begin
        RequestID := 'FSN-VENDOR-INV-NO';
        PosMenuLineTemp."Menu ID" := FSNVendorInvNo;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        exit(PosMenuLineTemp."Data ID");
    end;



}

