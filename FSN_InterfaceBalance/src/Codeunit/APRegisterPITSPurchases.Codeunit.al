codeunit 50061 "FSN AP-RegisterPITSPurchases"
{

    trigger OnRun()
    begin
        FillTable;
        RowsAffected := 0;
    end;

    var
        PITSPurchases: Record "FSN PITS_po";
        PurchaseInvoiceHeader: Record "Purch. Inv. Header";
        PurchaseCreditMemoHeader: Record "Purch. Cr. Memo Hdr.";
        RowsAffected: Integer;
        Store: Record "LSC Store";
        APProcessedPurchInv: Record "FSN AP - Pro Purch. Invoices";
        //APProcessedPurchCrMemo: Record "FSN AP - Pro Purch. Cr. Memo";
        PITPO: Record "FSN PITS_po";


    procedure FillTable()
    var
        Vendor1: Record "Vendor";
        Vendor2: Record "Vendor";
    begin
        PurchaseInvoiceHeader.RESET;
        //PurchaseInvoiceHeader.SETFILTER("Location Code", '<>CD');
        //PurchaseInvoiceHeader.SETRANGE(Processed,FALSE);
        //PurchaseInvoiceHeader.SETFILTER("Vendor Invoice No.", '<>R*&<>Q*');
        PurchaseInvoiceHeader.SETFILTER("Vendor Invoice No.", '<>R*');  //ITFSNPF06022017 Se quito Filtro de Quedan para que este tipo de documento llegue a interface.
        PurchaseInvoiceHeader.SETFILTER("Posting Date", '>%1', TODAY - 10);

        IF PurchaseInvoiceHeader.FIND('-') THEN
            REPEAT
                IF NOT APProcessedPurchInv.GET(PurchaseInvoiceHeader."No.") THEN BEGIN  //CSMQ180816
                                                                                        //if strlen(PurchaseInvoiceHeader."Vendor Invoice No.")>20 then
                    PITPO.SETRANGE(NUM_COMPROBANTE, COPYSTR(PurchaseInvoiceHeader."Vendor Invoice No.", 1, 20)); //DTE
                                                                                                                 //ELSE
                                                                                                                 //PITPO.SETRANGE(NUM_COMPROBANTE,PurchaseInvoiceHeader."Vendor Invoice No.");//ITFSNPF15022017  Compara que transaccion no se haya ingresado anteriormente.
                    PITPO.SETRANGE(prov_id, PurchaseInvoiceHeader."Buy-from Vendor No."); //ITFASANIPF2703
                    IF NOT PITPO.FIND('-') THEN BEGIN

                        PurchaseInvoiceHeader.CALCFIELDS(Amount, "Invoice Discount Amount", "Amount Including VAT");
                        CLEAR(PITSPurchases);
                        PITSPurchases.INIT;
                        PITSPurchases.NUM_COMPROBANTE := COPYSTR(PurchaseInvoiceHeader."Vendor Invoice No.", 1, 20);
                        PITSPurchases.Suc_id := PurchaseInvoiceHeader."Location Code";
                        IF Store.GET(PurchaseInvoiceHeader."Location Code") THEN
                            PITSPurchases.suc_nombre := Store.Name;//PurchaseInvoiceHeader."Ship-to Name";
                        PITSPurchases.Boleta_id := PurchaseInvoiceHeader."Order No.";
                        PITSPurchases.FECHA := PurchaseInvoiceHeader."Document Date";
                        PITSPurchases.FECHA_REGISTRO := PurchaseInvoiceHeader."Posting Date";  //CSMQ140316
                        PITSPurchases.fDIA := DATE2DMY(PurchaseInvoiceHeader."Posting Date", 1);
                        PITSPurchases.fMES := DATE2DMY(PurchaseInvoiceHeader."Posting Date", 2);
                        PITSPurchases.fANN := DATE2DMY(PurchaseInvoiceHeader."Posting Date", 3);
                        PITSPurchases.prov_id := PurchaseInvoiceHeader."Pay-to Vendor No.";
                        PITSPurchases.prov_nombre := PurchaseInvoiceHeader."Pay-to Name";

                        IF Vendor1.GET(PurchaseInvoiceHeader."Pay-to Vendor No.") AND (Vendor1."FSN Code Vendor" <> '') THEN BEGIN //WVILLALTA 09.23-
                            IF Vendor2.GET(Vendor1."FSN Code Vendor") THEN BEGIN
                                PITSPurchases.prov_id := Vendor2."No.";
                                PITSPurchases.prov_nombre := Vendor2.Name;
                            END;
                        END;
                        //WVILLALTA 09.23-
                        PITSPurchases.factura_subtotal := PurchaseInvoiceHeader.Amount;
                        PITSPurchases.factura_descuento := PurchaseInvoiceHeader."Invoice Discount Amount";
                        PITSPurchases.factura_imp_venta := PurchaseInvoiceHeader."Amount Including VAT" - PurchaseInvoiceHeader.Amount;
                        PITSPurchases.SALDO_COMPR := PurchaseInvoiceHeader."Amount Including VAT";
                        IF PurchaseInvoiceHeader."Expected Receipt Date" <> 0D THEN
                            PITSPurchases.Fecha_Documento := PurchaseInvoiceHeader."Expected Receipt Date"
                        ELSE
                            PITSPurchases.Fecha_Documento := PurchaseInvoiceHeader."Posting Date";
                        //PurchaseInvoiceHeader.Processed     := TRUE;  CSMQ180816

                        IF NOT PITSPurchases.INSERT(TRUE) THEN;
                        RowsAffected += 1;
                        //PurchaseInvoiceHeader.MODIFY(TRUE); CSMQ180816
                        //CSMQ180816-
                        APProcessedPurchInv.INIT;
                        APProcessedPurchInv."No." := PurchaseInvoiceHeader."No.";
                        IF APProcessedPurchInv.INSERT THEN;
                        //CSMQ180816+
                    END;  //itfsnPF15022017
                END;  //CSMQ180816
            UNTIL PurchaseInvoiceHeader.NEXT = 0;

        PurchaseCreditMemoHeader.RESET;
        //PurchaseCreditMemoHeader.SETFILTER("Location Code", '<>CD');
        //PurchaseCreditMemoHeader.SETRANGE(Processed, FALSE);  CSMQ180816
        PurchaseCreditMemoHeader.SETFILTER("Vendor Cr. Memo No.", '<>R*&<>Q*');
        PurchaseCreditMemoHeader.SETFILTER("Posting Date", '>%1', TODAY - 10);

        IF PurchaseCreditMemoHeader.FIND('-') THEN
            REPEAT
                //JH06092024 Se comenta la validacion a esta tabla para poder reutilizar el ID
                //IF NOT APProcessedPurchCrMemo.GET(PurchaseCreditMemoHeader."No.") THEN BEGIN  //CSMQ180816
                PurchaseCreditMemoHeader.CALCFIELDS(Amount, "Invoice Discount Amount", "Amount Including VAT");
                CLEAR(PITSPurchases);
                PITSPurchases.INIT;
                PITSPurchases.NUM_COMPROBANTE := COPYSTR(PurchaseCreditMemoHeader."Vendor Cr. Memo No.", 1, 20);
                PITSPurchases.Suc_id := PurchaseCreditMemoHeader."Location Code";
                IF Store.GET(PurchaseCreditMemoHeader."Location Code") THEN
                    PITSPurchases.suc_nombre := Store.Name;//PurchaseCreditMemoHeader."Ship-to Name";
                PITSPurchases.Boleta_id := PurchaseCreditMemoHeader."Return Order No.";
                PITSPurchases.FECHA := PurchaseCreditMemoHeader."Document Date";  //CSMQ140316
                PITSPurchases.FECHA_REGISTRO := PurchaseInvoiceHeader."Posting Date";
                PITSPurchases.fDIA := DATE2DMY(PurchaseCreditMemoHeader."Posting Date", 1);
                PITSPurchases.fMES := DATE2DMY(PurchaseInvoiceHeader."Posting Date", 2);
                PITSPurchases.fANN := DATE2DMY(PurchaseInvoiceHeader."Posting Date", 3);
                PITSPurchases.prov_id := PurchaseCreditMemoHeader."Pay-to Vendor No.";
                PITSPurchases.prov_nombre := PurchaseCreditMemoHeader."Pay-to Name";

                IF Vendor1.GET(PurchaseCreditMemoHeader."Pay-to Vendor No.") AND (Vendor1."FSN Code Vendor" <> '') THEN BEGIN //WVILLALTA 09.23-
                    IF Vendor2.GET(Vendor1."FSN Code Vendor") THEN BEGIN
                        PITSPurchases.prov_id := Vendor2."No.";
                        PITSPurchases.prov_nombre := Vendor2.Name;
                    END;
                END;                                                                                            //WVILLALTA 09.23-

                PITSPurchases.factura_subtotal := PurchaseCreditMemoHeader.Amount;
                PITSPurchases.factura_descuento := PurchaseCreditMemoHeader."Invoice Discount Amount";
                PITSPurchases.factura_imp_venta := PurchaseCreditMemoHeader."Amount Including VAT" - PurchaseCreditMemoHeader.Amount;
                PITSPurchases.SALDO_COMPR := PurchaseCreditMemoHeader."Amount Including VAT";
                PITSPurchases.TieneNota := 'si';
                PITSPurchases.NCVal := PurchaseCreditMemoHeader.Amount;
                PITSPurchases.NCnum := PurchaseCreditMemoHeader."Vendor Cr. Memo No.";
                IF PurchaseCreditMemoHeader."Expected Receipt Date" <> 0D THEN
                    PITSPurchases.Fecha_Documento := PurchaseCreditMemoHeader."Expected Receipt Date"
                ELSE
                    PITSPurchases.Fecha_Documento := PurchaseCreditMemoHeader."Posting Date";
                //PurchaseCreditMemoHeader.Processed     := TRUE; CSMQ180816

                IF PITSPurchases.INSERT(TRUE) THEN;
                RowsAffected += 1;
            //PurchaseCreditMemoHeader.MODIFY(TRUE);  CSMQ180816
            //CSMQ180816-
            //JH06092024 Se comenta la validacion a esta tabla para poder reutilizar el ID
            //APProcessedPurchCrMemo.INIT;
            //APProcessedPurchCrMemo."No." := PurchaseCreditMemoHeader."No.";
            //IF APProcessedPurchCrMemo.INSERT THEN;
            //CSMQ180816+
            //END;  //CSMQ180816
            UNTIL PurchaseCreditMemoHeader.NEXT = 0;

        IF RowsAffected > 0 THEN
            MESSAGE('Proceso Finalizado\%1 registros insertados', RowsAffected)
        ELSE
            MESSAGE('Proceso Finalizado\%1 registros insertados, ¿Ya se ejecutó antes?', RowsAffected);
    end;
}

