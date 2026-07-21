codeunit 50030 FSNPrint
{
    TableNo = "LSC POS Menu Line";
    trigger OnRun()
    begin
        GlobalPosMenuLine := Rec;
        case Command OF
            'FSNPRINT_X':
                PrintXZReportSV_X();
            'FSNPRINT_Z':
                PrintXZReportSV_Z();
            'FSNPRINT_Z_M':
                PrintZReportMensual(true);
            'PRINT_C_EXT':
                PrintCopyExt;
            'PRINTBILLEXT':
                begin
                    /*if OrderRT.Get("Current-RECEIPT") then begin
                        if FSNParameterRT.Get('ROBOT', 'PROCESS') and (OrderRT."Order Type Option" <> 4) then begin
                            if not FSNParameterRT.Activo then
                                PrintSlip("Current-RECEIPT")
                            else
                                PrintSlip("Current-RECEIPT");
                        end else
                            PrintSlip("Current-RECEIPT");

                    end;*/

                    IF POSTransactionBil.GET("Current-RECEIPT") THEN begin
                        if FSNParameterRT.Get('ROBOT', 'PROCESSCALL') AND FSNParameterRT.Activo then begin
                            if FSNParameterRT.Get('ROBOT', 'PROCESS') and (OrderRT."Order Type Option" <> 4) then begin
                                if not FSNParameterRT.Activo then begin
                                    IF PrintSlip(POSTransactionBil."Receipt No.") THEN;
                                    if delOrder.get(POSTransactionBil."Receipt No.") then begin
                                        delOrder."Printed OK" := TRUE;
                                        delOrder.MODIFY();
                                    end;
                                end;
                            end else begin
                                IF PrintSlip(POSTransactionBil."Receipt No.") THEN;
                                if delOrder.get(POSTransactionBil."Receipt No.") then begin
                                    delOrder."Printed OK" := TRUE;
                                    delOrder.MODIFY();
                                end;
                            end;
                        end else begin
                            if FSNParameterRT.get('ROBOT', 'SALES') then begin
                                if delOrder.get(POSTransactionBil."Receipt No.") then begin
                                    IF (delOrder."Order Type Option" <> 4) THEN BEGIN
                                        if not FSNParameterRT.Activo then
                                            IF PrintSlip(delOrder."Order No.") THEN BEGIN
                                                delOrder."Printed OK" := TRUE;
                                                delOrder.MODIFY(TRUE);
                                            END;
                                    END ELSE
                                        IF PrintSlip(delOrder."Order No.") THEN BEGIN
                                            delOrder."Printed OK" := TRUE;
                                            delOrder.MODIFY(TRUE);
                                        END;
                                END;
                            end else
                                IF PrintSlip(POSTransactionBil."Receipt No.") then;
                        end;
                    end;
                end;
            ELSE
        end;
    end;

    var
        delOrder: Record "LSC Delivery Order";
        Pr: Record "FSN Parameter";
        POSTransactionBil: Record "LSC POS Transaction";
        Text001: Label 'Make Pickup for Tender Type %1';
        CashMgm: Codeunit "LSC Cash Management";
        Store: Record "LSC Store";
        PosFuncProfile: Record "LSC POS Func. Profile";
        TSUtil: Codeunit "LSC POS Trans. Server Utility";
        Globals: Codeunit "LSC POS Session";
        TsOk: Boolean;
        PickUpWarnTmp: Record "LSC POS Pick Up Warning" temporary;
        PrintUtil: Codeunit "LSC POS Print Utility";
        NicopuPaymentEntry: Record "LSC Trans. Payment Entry";
        Nicopu: Decimal;
        NicopuSUM: Decimal;
        RunParameter: Option X,Z,Y;
        GlobalPosMenuLine: Record "LSC POS Menu Line";
        PrintUL: Codeunit "LSC POS Print Utility";
        POSGUI: Codeunit "LSC POS GUI";
        POSFunctions: Codeunit "LSC POS Functions";
        GenPosFunc: Record "LSC POS Func. Profile";
        PaymEntry: Record "LSC Trans. Payment Entry";
        TenderType: Record "LSC Tender Type";
        TendDeclEntry: Record "LSC Trans. Tender Declar. Entr";
        TempTendDeclEntry: Record "LSC Trans. Tender Declar. Entr" temporary;
        TempTransInfoCode: Record "LSC Trans. Infocode Entry" temporary;
        rTransaction: Record "LSC Transaction Header";
        Currency: Record "Currency";
        PeriodicDiscountInfoTEMP: Record "LSC Periodic Discount" temporary;
        rTransSafeEntry: Record "LSC Trans. Safe Entry";
        LocalTotal: Decimal;
        totSPOAmount: Decimal;
        Subtotal: Decimal;
        TipsAmount1: Decimal;
        TipsText1: Text;
        TipsAmount2: Decimal;
        vIVAS: Decimal;
        FiscalON: Boolean;
        OnlyFiscal: Boolean;
        TotalLCYInCurrency: Decimal;
        vFirstFechaCref: Date;
        vEfectivoTotal: Decimal;
        vChequeTotal: Decimal;
        vCofreEfectivo: Decimal;
        vCofreCheque: Decimal;
        IsDeliveryCopy: Boolean;
        Fecha: Date;
        gNoSuspPOSTransactionsVoided: Integer;
        Value: array[10] of Text[250];
        NodeName: array[32] of Text[50];
        TipsText2: Text;
        Text112: Label 'Tender declaration:';
        Text107: Label 'X-REPORT';
        Text106: Label 'Z-REPORT';
        TextNRC: Label 'NRC';
        TextRNC: Label 'NIT';
        TextGIRO: Label 'GIRO';
        TextCodTienda: Label 'Cod.Tienda:';
        TextCaja: Label 'Caja:';
        Text005: Label 'Total';
        Text300: Label 'Foreign Currency:';
        Text009: Label 'Float entry';
        DiffText: Label '   Difference';
        Text024: Label 'Total Discount';
        Text232: Label 'Points';
        Text230: Label 'System Voided';
        Text235: Label 'No. of Covers';
        Text236: Label 'No. of Split Trans.';
        Text237: Label 'Average of Covers per Table';
        Text238: Label 'Avg. Paying Cust. per Table';
        Text153: Label 'Transaction Server Error';
        Text161: Label '%1 Transactions are pending';
        PrintingCopyRollo: Record "FSN Printing Copy";
        AuditorRoll_lrep: Report "FSN RolloAuditor";
        POSSESSION: Codeunit "LSC POS Session";
        PaymTrans2: Record "LSC Trans. Payment Entry";
        PaymTrans3: Record "LSC Trans. Payment Entry";
        PaymTemp: Record "LSC Trans. Payment Entry" temporary;
        Terminal: Record "LSC POS Terminal";
        Staff: Record "LSC Staff";
        SCode: Code[20];
        Transaction: Record "LSC Transaction Header";
        Transaction2: Record "LSC Transaction Header";
        IncExpAccount: Record "LSC Income/Expense Account";
        IncExpEntry: Record "LSC Trans. Inc./Exp. Entry";
        SuspTrans: Record "LSC POS Transaction";
        DSTR1: Text[80];
        ZReportID: Code[10];
        FloatTotal: Decimal;
        RemoveTotal: Decimal;
        TendDeclEntry2: Record "LSC Trans. Tender Declar. Entr";
        IncExpEntry2: Record "LSC Trans. Inc./Exp. Entry";
        RecCount: Integer;
        TransServerWorkTable: Record "LSC Trans. Server Work Table";
        TransNotSent: Integer;
        SuspTransLine: Record "LSC POS Trans. Line";
        NoSuspended: Integer;
        NoSuspPrepayment: Integer;
        SuspPrepayment: Decimal;
        NoTables: Integer;
        NoSplitTrans: Integer;
        lText004: Label 'Unsent WarrHotel entries';
        WHBatchQueue: Record "LSC POS EFT Request";
        LineFound: Boolean;
        lSafeType: Integer;
        NoOfLines: Integer;
        TotalSafeType: Decimal;
        rCompanyInfo: Record "Company Information";
        rNoSeries: Record "No. Series";
        rNoSeriesLn: Record "No. Series Line";
        FirstTicket: Code[30];
        LastTicket: Code[30];
        rSalesEntry: Record "LSC Trans. Sales Entry";
        Venta: Decimal;
        Iva: Decimal;
        vTotal: Decimal;
        VentasG: Decimal;
        TotalIva: Decimal;
        TotalVentNcr: Decimal;
        TotalIvaNcr: Decimal;
        VentasE: Decimal;
        VentasEDev: Decimal;
        VentasNoSu: Decimal;
        VentasNoSuDev: Decimal;
        Percepcion: Decimal;
        PercepcionDev: Decimal;
        FirstFactCrf: Code[30];
        LastFactCrf: Code[30];
        Percibido: Decimal;
        FirstFactCf: Code[30];
        LastFactCf: Code[30];
        Retencion: Decimal;
        RetencionDev: Decimal;
        NoCorrelativoXZ: Code[30];
        ZReportHist: Record "FSN Z-Report History";
        FirstFactCrfDev: Code[30];
        LastFactCrfDev: Code[30];
        FirstFactCfDev: Code[30];
        LastFactCfDev: Code[30];
        vTotalDocDevolucion: Decimal;
        vTotalIvaDocDevolucion: Decimal;
        vVentasGravadasTotales: Decimal;
        vImpuestoIVATotales: Decimal;
        vTotalGravadoTotales: Decimal;
        vVentasExentasTotales: Decimal;
        vVentasNoSujetasTotales: Decimal;
        vVentasTotalesTotales: Decimal;
        vIVAPercibidoTotales: Decimal;
        vIVAPercibidoDevTotales: Decimal;
        vIVARetenidoTotales: Decimal;
        vNoDevoluciones: Integer;
        vEfectivoRetirado: Decimal;
        vChequeRetirado: Decimal;
        TextEfectivoRetirado: Label 'Efectivo Retirado';
        TextChequeRetirado: Label 'Cheque Retirado';
        TextEfectivoARetirar: Label 'Efectivo A Retirar';
        TextChequeARetirar: Label 'Cheque A Retirar';
        vFirstFactCredAut: Text[30];
        vLastFactCredAut: Text[30];
        vFirstFactCFAut: Text[30];
        vLastFactCFAut: Text[30];
        vTotalRetencionDev: Decimal;
        VentasEDevDocDev: Decimal;
        Transaction4: Record "LSC Transaction Header";
        vLastFechaCref: Date;
        vFirstFechaNocre: Date;
        vLastFechaNocre: Date;
        vFirstFechaFac: Date;
        vLastFechaFac: Date;
        vCESC: Decimal;
        vCESCTotales: Decimal;
        PrintingCopy: Record "FSN Printing Copy";
        PrintingCopyLastRecord: Integer;
        CurrPrintType: Option " ",X,Y,Z,YArqueo,ZZMensual;
        CurrPrintNo: Code[10];
        IsInvoice: Boolean;
        bSecondPrintActive: Boolean;
        LineLen: Integer;
        tmpDeal: Record "LSC Offer" temporary;
        TmpPrintedSalesEntry: Record "LSC Trans. Sales Entry" temporary;
        TmpPrintedDealPOSTransLine: Record "LSC POS Trans. Line" temporary;
        TotalAmt: Decimal;
        glTrans: Record "LSC Transaction Header";
        rBarras: Record "LSC Barcodes";
        vProductoTelefonica1: Code[20];
        vProductoTelefonica2: Code[20];
        vProductoTelefonica3: Code[20];
        vProductoTelefonica4: Code[20];
        RetailSetup: Record "LSC Retail Setup";
        PosPunto: Integer;
        iContador: Integer;
        jContador: Integer;
        Texto: array[2] of Text[75];
        FieldValue: array[10] of Text[100];
        TotFac: Text[100];
        vDecimalesTextoFactura: Text[100];
        TextImporteCheque: Text[30];
        CentenaMillom: Integer;
        Recordar: Integer;
        UdadMillon: Integer;
        CentenaMiles: Integer;
        DecenaMiles: Integer;
        UdadsMiles: Integer;
        DecenaMilon: Integer;
        Cantidades: Integer;
        NroDecimales: Integer;
        Longitud: Integer;
        Decenas: Integer;
        FSNUtility: Codeunit "FSN Utility";
        Text046: Label '** COPIA **';
        TextUnidad: Label 'Cant.';
        TextCodigo: Label 'Articulo';
        TextValor: Label 'Precio';
        Text500: Label 'Table';
        Text131: Label 'pcs';
        Text084: Label 'Line Discount';
        Text165: Label 'Coupon';
        Text085: Label 'Customer Discount';
        Text043: Label 'Total Saving';
        Text151: Label 'Cantidad de Artículos:';
        TextDescuentoVip: Label 'Ahorro Total VIP';
        Text216: Label 'SPO';
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        POSMenuLine: Record "LSC POS Menu Line";
        Processed: Boolean;
        MsgResult: text;
        InvLineLen: Integer;
        POSCtrl: Codeunit "LSC POS Control Interface";
        PosTransC: Codeunit "LSC POS Transaction";
        lSalesPersonTmp: Record "LSC Staff" temporary;
        SalesEntryStaff: Record "LSC Trans. Sales Entry";
        vendedor: Text;
        Nreceta: Text;
        TextReceta: Label 'N° DE RECETA:';
        FSNParameterRT: Record "FSN Parameter";
        OrderRT: Record "LSC Delivery Order";

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Print Utility", 'OnAfterPrintLine', '', true, true)]
    local procedure "LSC POS Print Utility_OnAfterPrintLine"
(
    var Transaction: Record "LSC Transaction Header";
    var Tray: Integer;
    var PrintBuffer: Record "LSC POS Print Buffer";
    var PrintBufferIndex: Integer;
    var LinesPrinted: Integer
)
    begin
        InsertPrintingCopy(PrintBuffer.Text, false, false, false, false);
    end;

    procedure InsertPrintingCopy(Texto: Text; Wide: Boolean; Bold: Boolean; High: Boolean; Italic: Boolean)
    begin

        PrintingCopy.INIT;

        if ValParameter then begin
            PrintingCopy.LOCKTABLE;
            PrintingCopy."Entry No." := LastEntryNoPrintCopy() + 1;
        end;

        PrintingCopy."Printing Type" := CurrPrintType;
        PrintingCopy."Printing No." := CurrPrintNo;
        PrintingCopy."Line Printed" := Texto;
        PrintingCopy.Wide := Wide;
        PrintingCopy.Bold := Bold;
        PrintingCopy.High := High;
        PrintingCopy.Italic := Italic;
        PrintingCopy.Date := TODAY;
        PrintingCopy.Time := TIME;
        PrintingCopy."Pos Terminal No." := Globals.TerminalNo;
        PrintingCopy."Store No." := Globals.StoreNo;
        PrintingCopy.INSERT;
        Commit();
    end;

    [EventSubscriber(ObjectType::Table, Database::"FSN Printing Copy", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "FSN Printing Copy_OnBeforeInsertEvent"
(
    var Rec: Record "FSN Printing Copy";
    RunTrigger: Boolean
)
    begin
        if not ValParameter then
            Rec."Entry No." := LastEntryNoPrintCopy + 1;
    end;

    procedure LastEntryNoPrintCopy(): Integer
    var
        PrintCopyTable: Record "FSN Printing Copy";
    begin

        IF PrintCopyTable.FINDLAST THEN
            exit(PrintCopyTable."Entry No.")
        else
            exit(1000);
    end;

    procedure ValParameter(): Boolean
    var
        Param: Record "FSN Parameter";
    begin
        IF Param.GET('PRINT', 'COPY') THEN BEGIN
            IF Param.activo then
                exit(true)
            else
                exit(false);
        END ELSE
            exit(false);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Print Utility", 'OnBeforePrintSalesSlip', '', true, true)]
    local procedure "LSC POS Print Utility_OnBeforePrintSalesSlip"
    (
        var Transaction: Record "LSC Transaction Header";
        var PrintBuffer: Record "LSC POS Print Buffer";
        var PrintBufferIndex: Integer;
        var LinesPrinted: Integer;
        var IsHandled: Boolean;
        var ReturnValue: Boolean
    )
    begin
        IsHandled := true;//Bloquea la Imprecion.
    end;

    procedure PrintCopyExt()
    var
        TmpTrans: Record "LSC Transaction Header";
        Parameter: Record "FSN Parameter";
        lRecordID: RecordID;
        lRecordRef: RecordRef;
        Text172: Label 'Print...';
        Text000: label 'Se reimprimira NCF: %1';
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;

    begin
        Clear(PosMenuLineTemp);
        PosMenuLineTemp.DeleteAll();
        Parameter.Reset();
        IF Parameter.GET('PRINTCOPY') then begin
            IF Parameter.Activo THEN begin
                if POSCtrl.GetActiveLookupRecordID(lRecordID) then begin
                    lRecordRef.Get(lRecordID);
                    lRecordRef.SetTable(TmpTrans);
                    IF PosConfirm(StrSubstNo(Text000, TmpTrans."FSN NCF"), true) THEN BEGIN
                        POSGUI.ScreenDisplay(Text172);
                        if (TmpTrans."FSN Document Type" in [TmpTrans."FSN Document Type"::"Credito Fiscal", TmpTrans."FSN Document Type"::Factura, TmpTrans."FSN Document Type"::"Nota Credito"]) then begin
                            PosMenuLineTemp.Init();
                            PosMenuLineTemp.Command := Parameter.Grupo;
                            PosMenuLineTemp."POS Help ID" := TmpTrans."Store No.";
                            PosMenuLineTemp."Current-POSID" := TmpTrans."POS Terminal No.";
                            PosMenuLineTemp."Key No." := TmpTrans."Transaction No.";
                            PosMenuLineTemp."Current-RECEIPT" := TmpTrans."Receipt No.";
                            PosMenuLineTemp.Insert();
                            RequestID := Parameter.Grupo;

                            FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                            //GIGAUNO.WSGenerarFactura(TmpTrans, 1, true);

                        end ELSE begin
                            PrintReceit(TmpTrans, 2, true);
                        end;
                    end else begin
                        EXIT;
                    end;
                END;
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Post Utility", 'OnAfterPostTransactionFiscalProcess', '', true, true)]
    local procedure "LSC POS Post Utility_OnAfterPostTransactionFiscalProcess"
(
    var TransactionHeader: Record "LSC Transaction Header";
    var FiscalProcessActive: Boolean;
    var FiscalProcessOk: Boolean;
    var POSTransaction: Record "LSC POS Transaction"
)
    var
        SalesEntry: Record "LSC Trans. Sales Entry";
        remissionB: Boolean;
        RetailSetup: Record "LSC Retail Setup";
        Parametrofsn: Record "FSN Parameter";
        TransIfoPX: Record "LSC Trans. Infocode Entry";
    begin
        remissionB := false;
        if TransactionHeader."Entry Status" = Transaction."Entry Status"::Voided then
            exit;

        if NOT (TransactionHeader."FSN Document Type" in [Transaction2."FSN Document Type"::Factura, Transaction2."FSN Document Type"::"Credito Fiscal", Transaction2."FSN Document Type"::"Nota Credito"]) then begin
            PrintReceit(TransactionHeader, 2, false);

            SalesEntry.Reset();
            SalesEntry.SETRANGE("Store No.", TransactionHeader."Store No.");
            SalesEntry.SETRANGE("POS Terminal No.", TransactionHeader."POS Terminal No.");
            SalesEntry.SETRANGE("Transaction No.", TransactionHeader."Transaction No.");
            if SalesEntry.Find('-') then
                repeat
                    if SalesEntry."FSN Remission No." <> '' then
                        remissionB := true;
                until SalesEntry.Next() = 0;

            RetailSetup.GET();
            IF NOT TransactionHeader."Sale Is Return Sale" AND (TransactionHeader."Gross Amount" * -1 >= RetailSetup."FSN Limit whitout VAT Reg. No.") then begin
                PrintReceit(TransactionHeader, 2, true);
            end else begin
                if NOT TransactionHeader."Sale Is Return Sale" AND (TransactionHeader."FSN Document Type" = TransactionHeader."FSN Document Type"::Ticket) and remissionB then
                    PrintReceit(TransactionHeader, 2, true);
            end;
        end;
        Parametrofsn.reset();
        if Parametrofsn.Get('PUNTOXPRESS', 'IMPRESIONMULT') and Parametrofsn.Activo then begin
            TransIfoPX.Reset();
            TransIfoPX.SetRange("Store No.", TransactionHeader."Store No.");
            TransIfoPX.SetRange("POS Terminal No.", TransactionHeader."POS Terminal No.");
            TransIfoPX.SetRange("Transaction No.", TransactionHeader."Transaction No.");
            TransIfoPX.SetFilter(Information, Parametrofsn.SetFilterData1 + Parametrofsn.SetFilterData2);
            if TransIfoPX.Find('-') then
                PrintReceit(TransactionHeader, 2, true);
        end;
    end;
    ////////////////////////////////////////////Print Receipt////////////////////////////////////////////////
    procedure PrintReceit(xTran: Record "LSC Transaction Header"; Tray: Integer; CopyR: Boolean): Boolean
    var
        DSTR1: Text[100];
    begin
        IF NOT PrintUL.OpenReceiptPrinter(2, 'TENDER', 'PRINTVIP_TICKET', 0, '') THEN
            EXIT(FALSE);

        IF Tray = 2 THEN BEGIN
            PrintSalesInfoExt(xTran, 2, CopyR);
        END;
        Commit();
        IF NOT PrintUL.ClosePrinter(2) THEN
            EXIT(FALSE);
    end;

    //////////////////////////////////////////////PrintSlip pedido//////////////////////////////////////////////////

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC Hospitality POS Startup", 'OnIdleTimerTickEvent', '', true, true)]
    local procedure "LSC Hospitality POS Startup_OnIdleTimerTickEvent"
    (
        ActiveDiningArea: Record "LSC Dining Area";
        var HospitalityTypeTemp: Record "LSC Hospitality Type";
        ActiveServiceFlow: Record "LSC Hospitality Service Flow"
    )
    var
        pr: Record "FSN Parameter";
    begin

        IF pr.GET('ROBOT', 'PRINT') THEN
            IF pr.Activo THEN
                exit;

        OnProcessPrintEvent();//Se separo el funcionamientos a un proceso aparte

    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnPOSEvent', '', true, true)]
    local procedure "LSC POS Controller_OnPOSEvent"
(
var PosEvent: Codeunit "LSC POS Event";
var SuppressEvent: Boolean
)
    var
        EPosCtrl: Codeunit "LSC POS Control Interface";
        OrderNo: Code[20];
        PosTrans: Record "LSC POS Transaction";
        POSMenulineTemp: Record "LSC POS Menu Line" temporary;
        HospiPOSStartup: codeunit "LSC Hospitality POS Startup";
        ErrorMessage: Label 'Pedido ya Fue asignado a %1';
        TEXT003: Label 'El N° pedido %1 esta siendo facturado en el N° %2';
        DelOrder: Record "LSC Delivery Order";
        InUseOnPos: code[10];
        ParameterC: Record "FSN Parameter";
        prv: Record "FSN Parameter";
        Terminal: Record "LSC POS Terminal";
    begin
        IF prv.GET('ROBOT', 'PRINT') THEN
            IF prv.Activo THEN begin
                if (PosEvent.ActivePanel = '#OFFLINE') then
                    if Terminal.get(POSSESSION.TerminalNo()) then
                        if (Terminal."Interface Profile" = '#FSNMASTER') then
                            OnProcessPrintEvent();
            end;
    end;

    Procedure OnProcessPrintEvent()
    var
        DelOrderTbl: Record "LSC Delivery Order";
        POSTransactionTbl: Record "LSC POS Transaction";
        FSNParameter: Record "FSN Parameter";
    begin
        DelOrderTbl.RESET;
        DelOrderTbl.SETRANGE("Printed OK", FALSE);
        IF DelOrderTbl.FIND('-') THEN
            REPEAT
                IF POSTransactionTbl.GET(DelOrderTbl."Order No.") THEN begin
                    if FSNParameter.Get('ROBOT', 'PROCESSCALL') AND FSNParameter.Activo then begin
                        if FSNParameterRT.Get('ROBOT', 'PROCESS') and (DelOrderTbl."Order Type Option" <> 4) then begin
                            IF POSSESSION.TerminalNo() = FSNParameterRT."Value Text 1" THEN
                                if not FSNParameterRT.Activo then begin
                                    IF PrintSlip(POSTransactionTbl."Receipt No.") THEN BEGIN
                                        DelOrderTbl."Printed OK" := TRUE;
                                        DelOrderTbl.MODIFY(TRUE);
                                    END;
                                end;
                        end else begin
                            if FSNParameterRT.Get('ROBOT', 'PROCESS') then
                                IF POSSESSION.TerminalNo() = FSNParameterRT."Value Text 1" THEN
                                    IF PrintSlip(POSTransactionTbl."Receipt No.") THEN BEGIN
                                        DelOrderTbl."Printed OK" := TRUE;
                                        DelOrderTbl.MODIFY(TRUE);
                                    END;
                        end;
                    end else begin
                        if FSNParameter.get('ROBOT', 'SALES') then begin
                            if FSNParameter.Activo then begin//20260615
                                IF (DelOrderTbl."Order Type Option" <> 4) THEN BEGIN
                                    IF POSSESSION.TerminalNo() = FSNParameter."Value Text 1" THEN
                                        IF PrintSlip(POSTransactionTbl."Receipt No.") THEN BEGIN
                                            DelOrderTbl."Printed OK" := TRUE;
                                            DelOrderTbl.MODIFY(TRUE);
                                        END;
                                END ELSE
                                    IF PrintSlip(POSTransactionTbl."Receipt No.") THEN BEGIN
                                        DelOrderTbl."Printed OK" := TRUE;
                                        DelOrderTbl.MODIFY(TRUE);
                                    END;
                            end else begin
                                IF PrintSlip(POSTransactionTbl."Receipt No.") THEN BEGIN
                                    DelOrderTbl."Printed OK" := TRUE;
                                    DelOrderTbl.MODIFY(TRUE);
                                END;
                            end;
                        end else
                            IF PrintSlip(POSTransactionTbl."Receipt No.") THEN BEGIN
                                DelOrderTbl."Printed OK" := TRUE;
                                DelOrderTbl.MODIFY(TRUE);
                            END;
                    end;
                end;
            UNTIL DelOrderTbl.NEXT = 0;
    end;

    /// <summary>
    ///  Print a slip for the transaction
    /// </summary>
    /// <param name="TransCC">Code of Transaction</param>
    /// <returns>si es exitoso el proceso</returns>
    local procedure PrintSlip(TransCC: Code[20]): Boolean
    var
        POSTrans: Record "LSC POS Transaction";
        PrintUtil: Codeunit "LSC POS Print Utility";
        xPosTrLines: Record "LSC POS Trans. Line";
        xStore: Record "LSC Store";
        rDeliveryOrder: Record "LSC Delivery Order";
        xDireccion: Text[250];
        xItem: Record "Item";
        xNewText: Text[50];
        xInt: Integer;
        xToInt: Integer;
        xStrFrom: Integer;
        xFreeText: Text[250];
        PosFunc: codeunit "LSC POS Functions";
        Tray: Integer;
        HoraEntrega: Time;
        xInfoCodeEntry: Record "LSC POS Trans. Infocode Entry";
        xStaff: Record "LSC Staff";
        FSNUtil: Codeunit "FSN Utility";
        TCommand, TransactorText, Tresponse, Response_Text : Text;
        countDescription: Integer;
        logitud: Integer;
    begin
        Clear(xDireccion);
        countDescription := 0;
        POSTrans.reset;
        if POSTrans.get(TransCC) then begin
            PosFunc.InitPosFunctions;
            PosFunc.PosTransDiscLoad(POSTrans."Receipt No.");
            Clear(PrintUtil);
            if not PrintUtil.OpenReceiptPrinter(2, 'PR', '', 0, POSTrans."Receipt No.") then
                exit(false);

            Tray := 2;
            HoraEntrega := POSTrans."Trans Time" + (30 * (60 * 1000));
            CLEAR(Value);
            DSTR1 := '#C######################################';
            Value[1] := 'Hora Entrega';
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, false, FALSE, FALSE));

            DSTR1 := '#C######################################';
            Value[1] := '';
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            DSTR1 := '#C######################################';
            Value[1] := '***** HORA SUGERIDA:' + FORMAT(HoraEntrega, 0, '<Hours12>:<Minutes,2>:<Seconds,2><Second dec.> <AM/PM>') + ' *****';
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            PrintUtil.PrintSeperator(Tray);

            DSTR1 := '#L######################################';
            // Pedido
            Value[1] := 'PEDIDO: ' + COPYSTR(POSTrans."Receipt No.", 11);
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            // Linea de Farmacia
            IF xStore.GET(POSTrans."Store No.") THEN
                Value[1] := 'FASANI: ' + xStore.Name
            ELSE
                Value[1] := 'FASANI: ____________________';
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            // Linea de Cliente
            Value[1] := 'Cliente ID: ' + POSTrans."Sell-to Contact No.";
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            // Nombre de Cliente
            Value[1] := 'Cliente: ' + COPYSTR(POSTrans.Comment, 1, 31);
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            // Direccion de Entrega
            CLEAR(xInfoCodeEntry);
            xInfoCodeEntry.SETRANGE("Receipt No.", POSTrans."Receipt No.");
            xInfoCodeEntry.SETRANGE(Infocode, 'DADDRESS2');
            IF xInfoCodeEntry.FIND('-') THEN BEGIN
                Value[1] := 'Area: ' + COPYSTR(xInfoCodeEntry.Information, 1, 30);
                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END;

            IF rDeliveryOrder.GET(POSTrans."Receipt No.") THEN BEGIN
                IF rDeliveryOrder.Address <> '' THEN BEGIN
                    xStrFrom := 1;
                    xFreeText := 'Calle/Col.: ' + rDeliveryOrder.Address;
                    xToInt := (STRLEN(xFreeText) DIV 38) + 1;
                    FOR xInt := 1 TO xToInt DO BEGIN
                        xNewText := COPYSTR(xFreeText, 1, 38);

                        Value[1] := xNewText;
                        IF xInt > 1 THEN
                            Value[1] := '  ' + xNewText;

                        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        xFreeText := COPYSTR(xFreeText, 39);
                    END;
                END;
                IF rDeliveryOrder."Grid Code" <> '' THEN BEGIN
                    Value[1] := 'Zona: ' + rDeliveryOrder."Grid Code";
                    PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;

                if rDeliveryOrder."FSN Directions" <> '' then begin
                    xDireccion := rDeliveryOrder."FSN Directions";

                end;
            END;

            /*xInfoCodeEntry.SETRANGE(Infocode, 'DDIRECTION');
            IF xInfoCodeEntry.FIND('-') THEN
                xDireccion := xInfoCodeEntry.Information
            ELSE
                xDireccion := '______________________________________';*/

            IF xDireccion = '' then
                xDireccion := '______________________________________';


            // Imprimir direccion fragmentada:
            xFreeText := 'Direccion: ' + xDireccion;

            xToInt := (STRLEN(xFreeText) DIV 38) + 1;
            FOR xInt := 1 TO xToInt DO BEGIN
                xNewText := COPYSTR(xFreeText, 1, 38);

                Value[1] := xNewText;
                IF xInt > 1 THEN
                    Value[1] := '  ' + xNewText;

                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                xFreeText := COPYSTR(xFreeText, 39);
            END;

            // Caja y Vendedor
            DSTR1 := 'CAJA: 999 VENDEDOR: 12345678901234567890';
            DSTR1 := '#L####### #L############################';
            Value[1] := 'Caja: ' + COPYSTR(POSTrans."POS Terminal No.", 4, 3);
            IF xStaff.GET(POSTrans."Staff ID") THEN
                Value[2] := 'Vendedor: ' + COPYSTR(xStaff."Name on Receipt", 1, 20)
            ELSE
                Value[2] := 'Vendedor: ' + '____________________';
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            if FSNParameterRT.Get('ROBOT', 'PROCESS') and (OrderRT."Order Type Option" <> 4) and (FSNParameterRT.Activo) then begin
                xInfoCodeEntry.Reset();
                xInfoCodeEntry.SETRANGE("Receipt No.", POSTrans."Receipt No.");
                xInfoCodeEntry.SETRANGE(Infocode, 'TEXT');
                xInfoCodeEntry.SETRANGE("Line No.", 70);
                if xInfoCodeEntry.Find('-') then
                    repeat
                        DSTR1 := '#L######################################';
                        Value[1] := 'Terminal: ' + xInfoCodeEntry.Information;
                        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    until xInfoCodeEntry.Next() = 0;

                xInfoCodeEntry.Reset();
                xInfoCodeEntry.SETRANGE("Receipt No.", POSTrans."Receipt No.");
                xInfoCodeEntry.SETRANGE(Infocode, 'TEXT');
                xInfoCodeEntry.SETRANGE("Line No.", 80);
                if xInfoCodeEntry.Find('-') then
                    repeat
                        DSTR1 := '#L######################################';
                        Value[1] := 'Ubicación: ' + xInfoCodeEntry.Information;
                        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    until xInfoCodeEntry.Next() = 0;
            end;

            PrintUtil.PrintSeperator(Tray);

            POSTrans.CALCFIELDS(Payment);
            IF POSTrans.Payment <> 0 THEN BEGIN
                xPosTrLines.RESET;
                xPosTrLines.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
                xPosTrLines.SETRANGE(xPosTrLines."Receipt No.", POSTrans."Receipt No.");
                xPosTrLines.SETRANGE(xPosTrLines."Entry Type", xPosTrLines."Entry Type"::Payment);
                xPosTrLines.SETRANGE(xPosTrLines."Entry Status", 0);
                if xPosTrLines.Find('-') then
                    repeat
                        //DSTR1 := '#L####### #L############################';
                        DSTR1 := '#L######################################';
                        Value[1] := COPYSTR(xPosTrLines.Description, 1, 20) + '.';
                        IF xPosTrLines.Number = '1' THEN begin
                            DSTR1 := '#L####### #L############################';
                            Value[2] := '$' + Format(xPosTrLines.Amount);
                        end;
                        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    until xPosTrLines.Next() = 0;
                /*CASE xPosTrLines.COUNT OF
                    0:
                        Value[1] := '';
                    1:
                        BEGIN
                            xPosTrLines.FINDFIRST;
                            Value[1] := COPYSTR(xPosTrLines.Description, 1, 20);
                        END;
                    ELSE
                        Value[1] := 'Mixto';
                END;*/
                //DSTR1 := '#L######################################';
                //PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));


                DSTR1 := '#L######################################';
                Value[1] := 'Venta :$' + FORMAT(POSTrans.Payment, 0, '<Precision,2:2><Standard Format,2>');
                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                Value[1] := FSNUTILITY.Num2Text(ABS(POSTrans.Payment)) + ' ' + 'DOLARES';
                DSTR1 := '#L######################################';
                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END;

            PrintUtil.PrintSeperator(Tray);

            IF NOT IsDeliveryCopy THEN BEGIN
                DSTR1 := '#L######################################';
                CLEAR(xPosTrLines);
                xPosTrLines.RESET;
                xPosTrLines.SETRANGE("Receipt No.", POSTrans."Receipt No.");
                xPosTrLines.SETRANGE("Entry Type", xPosTrLines."Entry Type"::Item);
                xPosTrLines.SETFILTER("Entry Status", '<>%1', xPosTrLines."Entry Status"::Voided);
                IF xPosTrLines.FIND('-') THEN
                    REPEAT
                        countDescription := 0;
                        IF xItem.GET(xPosTrLines.Number) THEN BEGIN
                            DSTR1 := '#L######################################';
                            Value[1] := '*** ' + COPYSTR(xItem."LSC Attrib 1 Code", 1, 30) + ' ***';
                            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                            IF xItem."FSN Showcase No." <> '' THEN BEGIN
                                DSTR1 := '#L######################################';
                                Value[1] := 'No. Estante:' + xItem."FSN Showcase No.";
                                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;

                            DSTR1 := '#L# #L##################################';
                            Value[1] := FORMAT(xPosTrLines.Quantity);

                            IF (xPosTrLines."Barcode No." <> '') THEN BEGIN
                                IF rBarras.GET(xPosTrLines."Barcode No.") THEN BEGIN
                                    Value[2] := COPYSTR(rBarras.Description, 1, 35);
                                    countDescription := StrLen(xItem.Description);
                                    PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                                END ELSE BEGIN
                                    Value[2] := COPYSTR(xItem.Description, 1, 35);
                                    countDescription := StrLen(xItem.Description);
                                    PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                END;
                            END
                            ELSE BEGIN
                                Value[2] := COPYSTR(xItem.Description, 1, 35);
                                countDescription := StrLen(xItem.Description);
                                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;

                            if countDescription > 35 then begin
                                DSTR1 := '#L# #L##################################';
                                Value[1] := ' ';
                                Value[2] := COPYSTR(xItem.Description, 36, countDescription);
                                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            end;

                            DSTR1 := 'PLU:1234567 1234567890123456789012345678';
                            DSTR1 := '#L######### #L##########################';
                            Value[1] := 'PLU:' + xPosTrLines.Number;
                            Value[2] := xPosTrLines."Unit of Measure";
                            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        END;
                    UNTIL xPosTrLines.NEXT = 0;
            END ELSE BEGIN
                DSTR1 := '#L######### #L##########################';
                Value[1] := 'COPIA';
                Value[2] := '******************';
                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END;//isCopy

            PrintUtil.PrintSeperator(Tray);

            CLEAR(xPosTrLines);
            xPosTrLines.SETRANGE("Receipt No.", POSTrans."Receipt No.");
            xPosTrLines.SETRANGE("Entry Type", xPosTrLines."Entry Type"::FreeText);
            //xPosTrLines.SETFILTER(xPosTrLines.Description, '<>%1', 'Prepagado');
            xPosTrLines.SETFILTER("Entry Status", '<>%1', xPosTrLines."Entry Status"::Voided);
            IF xPosTrLines.FIND('-') THEN
                REPEAT
                    DSTR1 := '#L######################################';
                    Value[1] := COPYSTR(xPosTrLines.Description, 1, 40);
                    PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                    IF STRLEN(xPosTrLines.Description) > 40 THEN BEGIN
                        Value[1] := '   ' + COPYSTR(xPosTrLines.Description, 41, 37);
                        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END;

                    IF STRLEN(xPosTrLines.Description) > 77 THEN BEGIN
                        Value[1] := '   ' + COPYSTR(xPosTrLines.Description, 78);
                        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END;
                UNTIL xPosTrLines.NEXT = 0;

            xInfoCodeEntry.RESET;
            xInfoCodeEntry.SETRANGE(xInfoCodeEntry."Receipt No.", POSTrans."Receipt No.");
            xInfoCodeEntry.SETRANGE(xInfoCodeEntry."Transaction Type", 0);
            xInfoCodeEntry.SETFILTER(xInfoCodeEntry."Line No.", '26|27|31');
            IF xInfoCodeEntry.FINDSET THEN BEGIN
                DSTR1 := '#C######################################';
                Value[1] := '------- MENSAJE PARA MOTO -------';
                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                DSTR1 := '#L######################################';
                REPEAT
                    xStrFrom := 1;
                    xFreeText := xInfoCodeEntry.Information;
                    xToInt := (STRLEN(xFreeText) DIV 38) + 1;
                    FOR xInt := 1 TO xToInt DO BEGIN
                        xNewText := COPYSTR(xFreeText, 1, 38);

                        Value[1] := xNewText;
                        IF xInt > 1 THEN
                            Value[1] := '  ' + xNewText;

                        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        xFreeText := COPYSTR(xFreeText, 39);
                    END;
                UNTIL xInfoCodeEntry.NEXT = 0;
            END;

            PrintUtil.PrintSeperator(Tray);

            DSTR1 := '#L######################################';
            Value[1] := 'Fecha: ' + FORMAT(WORKDATE, 10, '<Day,2>/<Month,2>/<Year4>') + ' ' + FORMAT(TIME, 14, '<Hours12>:<Minutes,2>:<Seconds,2> <AM/PM>');
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            Value[1] := '';
            Value[2] := '';
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            PrintUtil.ClosePrinter(2);
            TCommand := 'PRINTCARDVOUCHER';
            TransactorText := POSTrans."Receipt No.";
            FSNUtil.OninvokeGlobalChannelEvent(TransactorText, Tresponse, TCommand, POSMenuLine, Processed, Response_Text);
            exit(true);
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Print Utility", 'OnBeforePrintPOSSubHeader', '', true, true)]
    local procedure "LSC POS Print Utility_OnBeforePrintPOSSubHeader"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var PrintBuffer: Record "LSC POS Print Buffer";
        var PrintBufferIndex: Integer;
        var LinesPrinted: Integer;
        var DSTR1: Text[100];
        var IsHandled: Boolean
    )
    begin
        IsHandled := TRUE;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"FSN Utility", 'OnInvokeGlobalChannelEvent', '', true, true)]
    local procedure "FSN Utility_OnInvokeGlobalChannelEvent"
        (
            var XMLRequest: Text;
            var XMLResponse: Text;
            var RequestID: Text[50];
            var POSMenuLine: Record "LSC POS Menu Line";
            var Processed: Boolean;
            var MsgResult: Text
        )
    var
        TmpTrans: Record "LSC Transaction Header";
        PdelOrder: Record "LSC Delivery Order";
        RetailSetupBK: Record "LSC Retail Setup";
        pDelTrip: Record "FSN Delivery Trip";
        pIsConvert: Boolean;
        RetailSetup_l: Record "LSC Retail Setup";
        POSTrans: Record "LSC POS Transaction";
        Suggest: Integer;
    begin
        IF RequestID = 'PRINTCOPY' THEN BEGIN
            TmpTrans.RESET;
            TmpTrans.SETRANGE("Receipt No.", XMLRequest);
            TmpTrans.SETRANGE("FSN Document Type", TmpTrans."FSN Document Type"::Ticket);
            IF TmpTrans.FindFirst() THEN BEGIN
                PrintReceit(TmpTrans, 2, true);
            END;
        END;
    END;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Print Utility", 'OnBeforePrintPosSalesInfo', '', true, true)]
    local procedure "LSC POS Print Utility_OnBeforePrintPosSalesInfo"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var PrintBuffer: Record "LSC POS Print Buffer";
        var PrintBufferIndex: Integer;
        var LinesPrinted: Integer;
        var DSTR1: Text[100];
        var IsHandled: Boolean
    )
    begin
        IsHandled := TRUE;
    end;

    ///////////////////////////////////////////Print Encabezado//////////////////////////////////////////////

    procedure PrintHeaderExt(var Transaction: Record "LSC Transaction Header"; Tray: Integer; PrDate: Date; PrTime: Time)
    var
        Staff: Record "LSC Staff";
        DSTR1: Text[100];
        StaffName: Text[30];
        blankStr: Text[30];
        rNoSeries: Record "No. Series";
        rNoSeriesLn: Record "No. Series Line";
        rCust: Record "Customer";
        rCompanyInfo: Record "Company Information";
        rCountry: Record "Country/Region";
        rPosTerminal: Record "LSC POS Terminal";
        rPostCode: Record "Post Code";
        Correlativo: Code[20];
        cNoSeriesMgt: Codeunit "NoSeriesManagement";
        Transaccion: Integer;
        k: Integer;
        rTenderType: Record "LSC Tender Type";
        rTransPaymEntry: Record "LSC Trans. Payment Entry";
        CantPagos: Integer;
        TextNRC: Label 'NRC';
        TextRNC: Label 'NIT';
        TextGIRO: Label 'GIRO';
        TextCorrelativo: Label 'CORRELATIVO:';
        TextCodTienda: Label 'COD. TIENDA:';
        TextCaja: Label 'CAJA:';
        TextAutorizacion: Label 'AUTORIZACION:';
        TextTicket: Label 'TICKET';
        TextFecha: Label 'FECHA:';
        TextHora: Label 'HORA:';
        TextNIT: Label 'NIT:';
        TextDUI: Label 'DUI:';
        TextFirma: Label 'FIRMA:';
        TextUnidad: Label 'CANT.';
        TextCodigo: Label 'ARTICULO';
        TextValor: Label 'PRECIO';
        textTotal: Label 'SUBTOTAL';
        TextDUINIT: Label 'DUI/NIT:';
        TextNombre: Label 'NOMBRE:';
        TextSGD16: Label 'Supervisor:';
        rTransactionAfectada: Record "LSC Transaction Header";
        rStore: Record "LSC Store";
        xTransInfo: Record "LSC Trans. Infocode Entry";
        vDireccionCompleta: Text[200];
        vDireccionParte1: Text[100];
        vDireccionParte2: Text[100];
        vDireccionCortada: Boolean;
        TextCodCliente: Label 'COD. CLIENTE: ';
        Store: Record "LSC Store";
        RetailSetup: Record "LSC Retail Setup";
    begin
        Store.GET(Transaction."Store No.");
        //PrintSubHeader
        IF Tray = 2 THEN
            blankStr := PrintUL.StringPad(' ', LineLen - 38)
        ELSE
            IF Tray = 4 THEN
                blankStr := PrintUL.StringPad(' ', InvLineLen - 38);

        CLEAR(Value);
        IF Tray = 2 THEN BEGIN
            //Imprimir Nombre de la empresa...
            PrintUL.PrintLogo(2);
            rCompanyInfo.GET();
            DSTR1 := COPYSTR('#C######################################', 1);
            Value[1] := rCompanyInfo.Name;
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Imprimir Codigo Tipo Contribuyente y  No. Reg. Contribuyente de la empresa...
            rCompanyInfo.GET();
            DSTR1 := COPYSTR('#C######################################', 1);
            Value[1] := TextNRC + ':' + rCompanyInfo."FSN NRC";
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Imprimir NIT de la empresa...
            rCompanyInfo.GET();
            DSTR1 := COPYSTR('#C######################################', 1);
            Value[1] := TextRNC + ':' + rCompanyInfo."Federal ID No.";
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Imprimir Giro de la empresa...
            rCompanyInfo.GET();
            DSTR1 := COPYSTR('#C#######################################', 1);
            Value[1] := TextGIRO + '::' + COPYSTR(rCompanyInfo."FSN NRC Description", 1, 26);
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            DSTR1 := COPYSTR('#C#######################################', 1);
            Value[1] := COPYSTR(rCompanyInfo."FSN NRC Description", 26, 39);
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            Value[1] := '';
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Texto Devolucion
            IF Transaction."Sale Is Return Sale" THEN BEGIN
                DSTR1 := COPYSTR('        #C#########', 1);
                Value[1] := 'DEVOLUCION';
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, TRUE, FALSE));

                //Imprimir Linea en blanco...
                DSTR1 := COPYSTR('                     ', 1);
                Value[1] := '';
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END;

            //Imprimir Nombre de la tienda.
            DSTR1 := COPYSTR('#C#######################################', 1);
            Value[1] := Store."No." + '-' + Store.Name;
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, true, FALSE, FALSE));

            DSTR1 := COPYSTR('                     ', 1);
            Value[1] := '';
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Imprimir 1era. direccion de la tienda.
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := Store.Address;
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Imprimir 2da. direccion de la tienda.
            //Imprimir dirección solo si existe
            IF Store."Address 2" <> '' THEN BEGIN
                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := Store."Address 2";
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END;

            //Imprimir Municipio de la tienda
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := Store.County;
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Imprimir ciudad de la tienda
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := Store.City;
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            Value[1] := '';
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Imprimir telefono de la tienda.
            DSTR1 := COPYSTR('#L## #L#################################', 1);
            Value[1] := 'TEL:';
            Value[2] := Store."Phone No.";
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Imprimir el Correlativo..
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := 'Trans.:' + ' ' + FORMAT(Transaction."Receipt No.");
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Imprimir el No. de la Caja..
            DSTR1 := COPYSTR('#L#################      #R#############', 1);
            Value[1] := TextCodTienda + Store."No.";
            Value[2] := TextCaja + ' ' + Transaction."POS Terminal No.";
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            rNoSeries.RESET;
            IF rNoSeries.GET(Transaction."FSN No. Serie NCF") THEN BEGIN
                rNoSeriesLn.RESET;
                rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
                IF rNoSeriesLn.FINDFIRST THEN BEGIN
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := TextAutorizacion + ' ' + UPPERCASE(rNoSeriesLn."FSN Autorization");
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    //Imprimir el rango de ticket..
                    DSTR1 := COPYSTR('#L##########################', 1);
                    Value[1] := 'Del ' + rNoSeriesLn."Starting No.";
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                    DSTR1 := COPYSTR('#L##########################', 1);
                    Value[1] := 'al  ' + rNoSeriesLn."Ending No.";
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                    DSTR1 := COPYSTR('#L############################', 1);
                    Value[1] := 'Fecha autorizacion: ' + FORMAT(rNoSeriesLn."Starting Date", 0, '<Day,2>/<Month,2>/<Year4>');
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
            END;


            IF (Transaction."Manager ID" <> '') THEN BEGIN
                DSTR1 := '#L######### #L################';
                Staff.RESET;
                Staff.SETRANGE(Staff.ID, Transaction."Manager ID");
                IF Staff.FIND('-') THEN BEGIN
                    StaffName := Staff."Name on Receipt";
                    Value[1] := TextSGD16;
                    Value[2] := StaffName;
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
                END;
            END;

            rPosTerminal.RESET;
            rPosTerminal.SETRANGE("No.", Transaction."POS Terminal No.");
            rPosTerminal.SETRANGE("Store No.", Transaction."Store No.");
            IF rPosTerminal.FINDFIRST THEN BEGIN
                IF (Transaction."FSN No. Serie NCF" = rPosTerminal."FSN No. Serie NCF Ticket") THEN BEGIN
                    //Imprimir No. Ticket.
                    DSTR1 := COPYSTR('#L################################', 1);
                    Value[1] := TextTicket + ' ' + Transaction."FSN NCF";
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
            END;


            //Rereferencia Ticket para la devolucion..
            IF Transaction."Sale Is Return Sale" THEN BEGIN
                IF Transaction."FSN No. Serie NCF" = rPosTerminal."FSN No. Serie Devolucion" THEN BEGIN
                    DSTR1 := '#L############### #L####### #L##########';
                    Value[1] := 'DEVOL. REF.:FCF.';
                    Value[2] := Transaction."FSN NFC Affected";

                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                    DSTR1 := '#L############### #L#######';
                    Value[1] := 'DOC. DEVO: ';
                    Value[2] := Transaction."FSN NCF";
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END


                ELSE BEGIN

                    DSTR1 := '#L############### #L##################';
                    Value[1] := 'DEVOL. REF.:TICK.';
                    Value[2] := Transaction."FSN NFC Affected";
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));


                END;
            END;

            //Imprimir Hora y Fecha.
            CLEAR(Value);
            DSTR1 := '#L##### #L######### #R###### #R#########';
            Value[1] := TextFecha;
            Value[2] := FORMAT(PrDate, 0, '<Day,2>/<Month,2>/<Year4>');
            Value[3] := FORMAT(TextHora);
            Value[4] := FORMAT(TIME, 0, '<Hours12>:<Minutes,2> <AM/PM>');
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            Value[1] := '';
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            IF Transaction."Customer No." = '' THEN BEGIN
                IF Transaction."FSN NRC Description" <> '' THEN BEGIN
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := Transaction."FSN NRC Description";
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
                IF Transaction."FSN DUI" <> '' THEN BEGIN
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := TextDUI + ' ' + Transaction."FSN DUI";
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
                IF Transaction."FSN NIT" <> '' THEN BEGIN
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := TextNIT + ' ' + Transaction."FSN NIT";
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
            END;

            //Imprimir informacion del cliente.
            rCust.RESET;
            IF rCust.GET(Transaction."Customer No.") THEN BEGIN
                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := TextCodCliente + rCust."No.";
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                DSTR1 := COPYSTR('#L######################################', 1);
                IF Transaction.Comment = '' then
                    Value[1] := rCust.Name
                else
                    Value[1] := Transaction.Comment;
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                //Imprimir direccion del cliente
                /*DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := rCust.Address;
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));*/

                //Imprimir direccion 2 del cliente
                /*IF rCust."Address 2" <> '' THEN BEGIN
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := rCust."Address 2";
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;*/

                //Imprimir codigo de ciudad del cliente
                IF rCountry.GET(rCust."Country/Region Code") THEN BEGIN
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := rCountry.Name;
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;

                //Imprimir codigo de NIT y DUI del cliente
                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := TextNIT + ' ' + rCust."VAT Registration No.";
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := TextDUI + ' ' + rCust."FSN DUI";
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := TextNRC + ': ' + rCust."FSN NRC";
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END;

            //Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            RetailSetup.GET();
            IF Transaction."Sale Is Return Sale" OR (Transaction."Gross Amount" * -1 >= RetailSetup."FSN Limit whitout VAT Reg. No.") THEN BEGIN
                rPosTerminal.RESET;
                rPosTerminal.SETRANGE("No.", Transaction."POS Terminal No.");
                rPosTerminal.SETRANGE("Store No.", Transaction."Store No.");
                IF rPosTerminal.FINDFIRST THEN BEGIN
                    IF (Transaction."FSN No. Serie NCF" = rPosTerminal."FSN No. Serie NCF Ticket") OR (Transaction."FSN No. Serie NCF" = rPosTerminal."FSN No. Serie Devolucion") THEN BEGIN
                        //Imprimir Firma
                        DSTR1 := COPYSTR('#L####### #L############################', 1);
                        Value[1] := TextFirma;
                        Value[2] := '________________________________________';
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        //Imprimir Linea en blanco...
                        DSTR1 := COPYSTR('                     ', 1);
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END;
                END;
            END;

            //Imprimir Linea en blanco...
            /*DSTR1 := COPYSTR('                     ', 1);
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));*/
        END;
    END;
    //////////////////////////////////////////Print DETALLE Receipt///////////////////////////////////////////
    procedure PrintSalesInfoExt(var Transaction: Record "LSC Transaction Header"; Tray: Integer; Copy: Boolean)
    var
        TransInfoCode: Record "LSC Trans. Infocode Entry";
        Customer: Record "Customer";
        SalesEntry: Record "LSC Trans. Sales Entry";
        Item: Record "Item";
        PeriodicDiscount: Record "LSC Periodic Discount";
        TransInfoEntry, TransIfoPX, TransPXInf : Record "LSC Trans. Infocode Entry";
        POSTerminal: Record "LSC POS Terminal";
        ItemPosTextHeader: Record "LSC Item POS Text Header";
        ItemPosTextLine: Record "LSC Item POS Text Line";
        IncExpAcc: Record "LSC Income/Expense Account";
        POSTrans: Record "LSC POS Transaction";
        ItemName: Text[50];
        SalesLineAmount: Decimal;
        SalesAmountVAT: array[5] of Decimal;
        VATPerc: array[5] of Decimal;
        VATAmount: array[5] of Decimal;
        VATCode: array[5] of Code[10];
        PrintItemNo: Integer;
        VATPrinted: Boolean;
        discText: Text[30];
        discountSection: Boolean;
        totalCustItemDisc: Decimal;
        PerDiscOffArr: array[250] of Code[20];
        PerDiscOffAmtArr: array[250] of Decimal;
        PerDiscOffArrCount: Integer;
        OrderByDepartment: Boolean;
        LastDepartment: Code[10];
        ItemTranslate: Record "Item Translation";
        totalNumberOfItems: Decimal;
        totalSavings: Decimal;
        SalesEntry2: Record "LSC Trans. Sales Entry";
        LinkedItems: Record "LSC Linked Item";
        CountItemOk: Boolean;
        LineCount: Integer;
        TotalAmtForSummary: Decimal;
        DiscountOnBlockPrintOffers: Decimal;
        ParentItemLine: Record "LSC Trans. Sales Entry";
        ParentItem: Record Item;
        RecipeBufferTEMP: Record "LSC Trans. Sales Entry" temporary;
        RecipeBufferDetailTEMP_l: Record "LSC Trans. Discount Entry" temporary;
        StringLenBeforeSplitLine: Integer;
        TotalVentG: Decimal;
        TotalVentE: Decimal;
        TotalNoSuj: Decimal;
        Descuento: Decimal;
        CantLinFact: Integer;
        rVATPostingSetup: Record "VAT Posting Setup";
        Impuesto: Decimal;
        Precio: Decimal;
        SubtotalLinea: Decimal;
        TotalPercepcion: Decimal;
        TotalRetencion: Decimal;
        TotalLetras: Text[100];
        TextGravado: Label 'G';
        TextNSujeto: Label 'NS';
        TextExento: Label 'E';
        TextTotVentasG: Label 'G=Ventas Gravadas:';
        TextTotVentasE: Label 'E=Ventas Exentas:';
        TextVentNoSuj: Label 'Ventas No Sujetas:';
        TextSubTotal: Label 'Sub-Total:';
        TextDescuento: Label 'Ahorro Total:';
        TextTotal: Label 'TOTAL:';
        rSalesPerson: Record "Salesperson/Purchaser";
        rStaff1: Record "LSC Staff";
        rPosTerminal: Record "LSC POS Terminal";
        vSalesPersonNo: array[30] of Text[100];
        vAgregarSalesPersonNo: Integer;
        vIncomeExpense: Boolean;
        vVendedor: Text[90];
        vMediosPago: array[30] of Text[90];
        LineCountRemision: Integer;
        vInfoAmountTotal: Decimal;
        vTelefono: Text[10];
        EsRemision: Boolean;
        OriginalTrans: Record "LSC Transaction Header";
        vTipoPaquete: Text[150];
        filtro, ComentarioPX, xNewText : Text;
        Parametrofsn: Record "FSN Parameter";
        CurrentLine: Text[250];
        NComentario: Text[50];
        PInicial: Integer;
        Cespacio: Integer;
    begin
        vVendedor := '';
        if Transaction."Entry Status" = Transaction."Entry Status"::Voided then
            exit;
        //PrintSalesInfo
        StringLenBeforeSplitLine := 11;
        PrintHeaderExt(Transaction, 2, Transaction.Date, Transaction.Time);
        //Determinar si es una transaccion de Nota de Remision
        IF Transaction."FSN Remission No." THEN
            EsRemision := TRUE
        ELSE
            IF Transaction."Retrieved from Receipt No." = '' THEN
                EsRemision := FALSE
            ELSE BEGIN
                //Chequear si la transaccion original era de Remision
                CLEAR(OriginalTrans);
                OriginalTrans.SETRANGE("Receipt No.", Transaction."Retrieved from Receipt No.");
                IF OriginalTrans.FIND('-') THEN
                    EsRemision := OriginalTrans."FSN Remission No."
                ELSE
                    EsRemision := FALSE;
            END;
        IF GenPosFunc."Multiple Items Symbol" = '' THEN
            GenPosFunc."Multiple Items Symbol" := ' x ';

        TransInfoCode.SETRANGE("Store No.", Transaction."Store No.");
        TransInfoCode.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
        TransInfoCode.SETRANGE("Transaction No.", Transaction."Transaction No.");
        TransInfoCode.SETRANGE("Transaction Type", TransInfoCode."Transaction Type"::Header);

        IF Copy THEN BEGIN
            DSTR1 := '#C##################';
            FieldValue[1] := ' ** COPIA ** ';
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(FieldValue, DSTR1), true, false, true, false));
            PrintUL.PrintSeperator(Tray);
        END;
        IF Transaction."Entry Status" = Transaction."Entry Status"::Training THEN
            PrintUL.PrintTrainingText(Tray);

        PerDiscOffArrCount := 0;
        totalCustItemDisc := 0;

        CLEAR(totalNumberOfItems);
        CLEAR(totalSavings);

        LineCount := 0;
        CLEAR(VATCode);
        CLEAR(VATPerc);
        CLEAR(VATAmount);
        CLEAR(SalesAmountVAT);
        CLEAR(SalesEntry);
        CLEAR(Value);
        tmpDeal.DELETEALL;
        TmpPrintedSalesEntry.DELETEALL;
        TmpPrintedDealPOSTransLine.DELETEALL;
        IF GenPosFunc."Print Disc/Cpn Info on Slip" IN
         [GenPosFunc."Print Disc/Cpn Info on Slip"::"Detail for each line and Sub-total",
          GenPosFunc."Print Disc/Cpn Info on Slip"::"Summary information below Sub-total"] THEN BEGIN
            PeriodicDiscountInfoTEMP.RESET;
            PeriodicDiscountInfoTEMP.DELETEALL;
            Subtotal := 0;
        END;
        TotalAmt := 0;
        TipsAmount1 := 0;
        TipsText1 := '';
        TipsAmount2 := 0;
        TipsText2 := '';
        glTrans := Transaction;
        SalesEntry.SETRANGE("Store No.", Transaction."Store No.");
        SalesEntry.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
        SalesEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
        OrderByDepartment := GenPosFunc."Receipt Printing by Category";
        IF OrderByDepartment THEN
            SalesEntry.SETCURRENTKEY("Item Category Code");

        IF SalesEntry.FIND('-') THEN BEGIN
            PrintItemNo := 0;
            IF POSTerminal.GET(SalesEntry."POS Terminal No.") THEN
                IF POSTerminal."Receipt Setup Location" = POSTerminal."Receipt Setup Location"::Store THEN BEGIN
                    CASE Store."Item No. on Receipt" OF
                        Store."Item No. on Receipt"::"Item Number":
                            PrintItemNo := 1;
                        Store."Item No. on Receipt"::"Barcode/Item Number":
                            PrintItemNo := 2;
                    END;
                END ELSE BEGIN
                    CASE POSTerminal."Item No. on Receipt" OF
                        POSTerminal."Item No. on Receipt"::"Item Number":
                            PrintItemNo := 1;
                        POSTerminal."Item No. on Receipt"::"Barcode/Item Number":
                            PrintItemNo := 2;
                    END;
                END;

            LastDepartment := '';
            RecipeBufferTEMP.RESET;
            RecipeBufferTEMP.DELETEALL;
            RecipeBufferDetailTEMP_l.RESET;
            RecipeBufferDetailTEMP_l.DELETEALL;

            IF NOT IsInvoice THEN BEGIN
                //Se agregó cabecera detalle
                PrintUL.PrintSeperator(Tray);
                rPosTerminal.RESET;
                rPosTerminal.SETRANGE("No.", Transaction."POS Terminal No.");
                rPosTerminal.SETRANGE("Store No.", Transaction."Store No.");
                IF rPosTerminal.FINDFIRST THEN BEGIN
                    //IF (Transaction."FSN No. Serie NCF" = rPosTerminal."FSN No. Serie NCF Ticket") OR
                    //cabecera devolucion
                    //(Transaction."FSN No. Serie NCF" = rPosTerminal."FSN No. Serie Devolucion") THEN BEGIN
                    //Imprimir cabecera del detalle
                    DSTR1 := COPYSTR('#L##    #L######        #R#### #R#######', 1);
                    Value[1] := TextUnidad;
                    Value[2] := TextCodigo;
                    Value[3] := TextValor;
                    Value[4] := TextTotal;
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    //END;
                END;

                IF Transaction."Table No." <> 0 THEN BEGIN
                    CLEAR(Value);
                    Value[1] := Text500 + ':';
                    Value[2] := FORMAT(Transaction."Table No.");
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
                PrintUL.PrintSeperator(Tray);
            END
            //cabecera detalle factura
            ELSE
                IF IsInvoice THEN BEGIN
                END;
            vInfoAmountTotal := 0;

            CLEAR(SalesEntry);
            SalesEntry.SETRANGE("Store No.", Transaction."Store No.");
            SalesEntry.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
            SalesEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
            IF OrderByDepartment THEN
                SalesEntry.SETCURRENTKEY("Item Category Code");
            IF SalesEntry.FIND('-') THEN
                REPEAT
                    IF Item.GET(SalesEntry."Item No.") THEN BEGIN
                        IF (SalesEntry."Barcode No." <> '') THEN BEGIN
                            IF rBarras.GET(SalesEntry."Barcode No.") THEN
                                ItemName := COPYSTR(rBarras.Description, 1, 35)
                            ELSE
                                ItemName := COPYSTR(Item.Description, 1, 35);
                        END
                        ELSE BEGIN
                            ItemName := COPYSTR(Item.Description, 1, 35);
                        END;
                    END ELSE
                        ItemName := SalesEntry."Item No.";

                    IF SalesEntry."Parent Line No." = 0 THEN BEGIN
                        ParentItem := Item;
                        ParentItemLine := SalesEntry;
                    END;

                    IF (ParentItem."LSC Skip Compr. When Printed" = FALSE) AND
                      (NOT SalesEntry."Deal Line")
                    THEN
                        InsertIntoRecipeBuffer(SalesEntry, RecipeBufferTEMP, ParentItemLine, RecipeBufferDetailTEMP_l);

                    POSTerminal.GET(Transaction."POS Terminal No.");
                    IF POSTerminal."Print Total Savings" THEN BEGIN
                        totalSavings := totalSavings + SalesEntry."Discount Amount";
                    END;

                    IF POSTerminal."Print Number of Items" THEN BEGIN
                        IF (SalesEntry.Quantity < 0) THEN BEGIN
                            CountItemOk := TRUE;
                            IF SalesEntry."Linked No. not Orig." THEN BEGIN
                                SalesEntry2.RESET;
                                SalesEntry2.COPYFILTERS(SalesEntry);
                                IF SalesEntry2.FIND('-') THEN BEGIN
                                    REPEAT
                                        IF (SalesEntry2."Item No." <> SalesEntry."Item No.") AND SalesEntry2."Orig. of a Linked Item List" THEN BEGIN
                                            LinkedItems.RESET;
                                            LinkedItems.SETRANGE("Item No.", SalesEntry2."Item No.");
                                            LinkedItems.SETRANGE("Linked Item No.", SalesEntry."Item No.");
                                            LinkedItems.SETFILTER("Sales Type", '%1|%2', '', Transaction."Sales Type");
                                            IF LinkedItems.FINDFIRST THEN BEGIN
                                                IF LinkedItems."Deposit Item" THEN
                                                    CountItemOk := FALSE;
                                            END;
                                        END;
                                    UNTIL (SalesEntry2.NEXT = 0) OR NOT CountItemOk;
                                END;
                            END;

                            IF CountItemOk THEN BEGIN
                                IF SalesEntry."UOM Quantity" <> 0 THEN
                                    totalNumberOfItems := totalNumberOfItems + ABS(SalesEntry."UOM Quantity")
                                ELSE
                                    totalNumberOfItems := totalNumberOfItems + ABS(SalesEntry.Quantity);

                            END;

                        END;
                    END;

                    IF Customer.GET(Transaction."Customer No.") THEN
                        IF Customer."Language Code" <> '' THEN
                            IF ItemTranslate.GET(SalesEntry."Item No.", SalesEntry."Variant Code", Customer."Language Code") THEN
                                IF ItemTranslate.Description <> '' THEN
                                    ItemName := ItemTranslate.Description;

                    IF SalesEntry."Deal Line" THEN BEGIN
                        PrintUL.PrintDeal(SalesEntry, Tray, PrintItemNo);
                        PrintUL.CollectDiscInfo(SalesEntry, Tray, TotalAmt, Subtotal, PeriodicDiscountInfoTEMP);
                        IF GenPosFunc."Print Disc/Cpn Info on Slip" =
                          GenPosFunc."Print Disc/Cpn Info on Slip"::"No printing"
                        THEN
                            SalesLineAmount := SalesEntry."Net Amount" + SalesEntry."VAT Amount"
                        ELSE
                            SalesLineAmount :=
                              SalesEntry."Net Amount" + SalesEntry."VAT Amount"
                              - SalesEntry."Discount Amount";
                        IF GenPosFunc."Print Disc/Cpn Info on Slip" =
                            GenPosFunc."Print Disc/Cpn Info on Slip"::"Detail information for each line"
                        THEN
                            TotalAmt := TotalAmt + SalesLineAmount
                        ELSE
                            IF GenPosFunc."Print Disc/Cpn Info on Slip" =
                              GenPosFunc."Print Disc/Cpn Info on Slip"::"No printing"
                            THEN
                                TotalAmt := TotalAmt + SalesLineAmount;
                    END ELSE BEGIN
                        IF GenPosFunc."Print Disc/Cpn Info on Slip" =
                          GenPosFunc."Print Disc/Cpn Info on Slip"::"No printing"
                        THEN
                            SalesLineAmount := SalesEntry."Net Amount" + SalesEntry."VAT Amount"
                        ELSE
                            SalesLineAmount :=
                              SalesEntry."Net Amount" + SalesEntry."VAT Amount"
                              - SalesEntry."Discount Amount";
                        DiscountOnBlockPrintOffers := PrintUL.ReturnDiscountBlockPrinting(SalesEntry);
                        IF GenPosFunc."Print Disc/Cpn Info on Slip" IN
                             [GenPosFunc."Print Disc/Cpn Info on Slip"::"Detail information for each line",
                              GenPosFunc."Print Disc/Cpn Info on Slip"::"No printing"]
                        THEN
                            TotalAmt := TotalAmt + SalesLineAmount;

                        IF GenPosFunc."Print Disc/Cpn Info on Slip" IN
                          [GenPosFunc."Print Disc/Cpn Info on Slip"::"Detail information for each line",
                          GenPosFunc."Print Disc/Cpn Info on Slip"::"Detail for each line and Sub-total",
                          GenPosFunc."Print Disc/Cpn Info on Slip"::"Summary information below Sub-total"]
                        THEN
                            SalesLineAmount := SalesLineAmount + DiscountOnBlockPrintOffers;

                        IF (ABS(SalesEntry.Quantity) <> 1) OR
                           ((SalesEntry."UOM Quantity" <> 0) AND (ABS(SalesEntry."UOM Quantity") <> 1)) OR
                           SalesEntry."Scale Item" OR
                           SalesEntry."Price in Barcode"
                        THEN BEGIN
                            DSTR1 := '#L######################################';
                            IF ParentItem."LSC Skip Compr. When Printed" THEN
                                PrintUL.PrintLineHospitality(Tray, 300, 4, NodeName, Value, DSTR1, FALSE, FALSE, FALSE, FALSE, SalesEntry);
                            CLEAR(Value);
                            DSTR1 := '   #L################### #N########## #R';
                            IF SalesEntry."Scale Item" OR SalesEntry."Price in Barcode" THEN BEGIN
                                IF SalesEntry."Weight Manually Entered" THEN
                                    DSTR1 := 'MAN #L################## #N########## #R';
                                Value[1] := Value[1] + POSFunctions.FormatWeight(-SalesEntry.Quantity, SalesEntry."Unit of Measure") +
                                            ' ' + GenPosFunc."Multiple Items Symbol" + ' ';
                                Value[1] := Value[1] + POSFunctions.FormatPricePrUnit(SalesEntry.Price, SalesEntry."Unit of Measure");
                            END ELSE BEGIN
                                IF SalesEntry."Unit of Measure" = '' THEN
                                    SalesEntry."Unit of Measure" := Text131;
                                IF (SalesEntry."UOM Quantity" <> 0) THEN BEGIN
                                    SalesEntry.Quantity := SalesEntry."UOM Quantity";
                                    SalesEntry.Price := SalesEntry."UOM Price";
                                END;
                                Value[1] :=
                                  POSFunctions.FormatQty(-SalesEntry.Quantity) + ' ' + LOWERCASE(SalesEntry."Unit of Measure") +
                                  ' ' + GenPosFunc."Multiple Items Symbol" + ' ';
                                Value[1] := Value[1] + POSFunctions.FormatPrice(SalesEntry.Price);
                            END;
                            IF ParentItem."LSC Skip Compr. When Printed" THEN
                                PrintUL.PrintLineHospitality(Tray, 300, 6, NodeName, Value, DSTR1,
                    FALSE, (SalesEntry."Periodic Discount" <> 0), FALSE, FALSE, SalesEntry);
                        END ELSE BEGIN
                            DSTR1 := '#L###################### #N########## #R';
                            IF ParentItem."LSC Skip Compr. When Printed" THEN
                                PrintUL.PrintLineHospitality(Tray, 300, 9, NodeName, Value, DSTR1,
                    FALSE, (SalesEntry."Periodic Discount" <> 0), FALSE, FALSE, SalesEntry);
                        END;
                        IF GenPosFunc."Print Free Text on Receipt" THEN
                            PrintUL.PrintFreeTextLines(SalesEntry, Tray, FALSE);
                        PrintUL.CollectDiscInfo(SalesEntry, Tray, TotalAmt, Subtotal, PeriodicDiscountInfoTEMP);

                        IF ItemPosTextHeader.GET(
                          SalesEntry."Item No.", ItemPosTextHeader."Text Type"::"Receipt Text", Store."Language Code")
                        THEN BEGIN
                            ItemPosTextLine.SETRANGE("Item No.", SalesEntry."Item No.");
                            ItemPosTextLine.SETRANGE("Text Type", ItemPosTextHeader."Text Type"::"Receipt Text");
                            ItemPosTextLine.SETRANGE("Language Code", Store."Language Code");
                            IF ItemPosTextLine.FIND('-') THEN
                                REPEAT
                                    Value[1] := FORMAT(SalesEntry."Line No.");
                                    NodeName[1] := 'Line No.';
                                    Value[2] := ItemPosTextLine.Text;
                                    NodeName[2] := 'Extra Info Line';
                                    PrintUL.PrintLine(Tray, ItemPosTextLine.Text);
                                    PrintUL.AddPrintLine(350, 2, NodeName, Value, DSTR1, FALSE, FALSE, FALSE, FALSE, Tray);
                                UNTIL ItemPosTextLine.NEXT = 0;
                        END;

                        TransInfoEntry.SETRANGE("Store No.", Transaction."Store No.");
                        TransInfoEntry.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
                        TransInfoEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
                        TransInfoEntry.SETRANGE("Transaction Type", TransInfoEntry."Transaction Type"::"Sales Entry");
                        TransInfoEntry.SETRANGE("Line No.", SalesEntry."Line No.");
                        IF TransInfoEntry.FIND('-') THEN BEGIN
                            IF (EsRemision) AND (TransInfoEntry.Information <> '') THEN BEGIN
                                IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                                    PrintLineRemision(Tray, FALSE, TransInfoEntry.Information, TransInfoEntry."Info. Amt.");
                                    vInfoAmountTotal := vInfoAmountTotal + TransInfoEntry."Info. Amt.";
                                END ELSE BEGIN
                                    IF Transaction."Customer No." = 'C000002' THEN BEGIN
                                        PrintLineRemision(Tray, FALSE, TransInfoEntry.Information, TransInfoEntry.Amount);
                                        vInfoAmountTotal := vInfoAmountTotal + TransInfoEntry.Amount;
                                    END
                                    ELSE BEGIN
                                        IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                                            PrintLineRemision(Tray, FALSE, TransInfoEntry.Information, ROUND(TransInfoEntry."Info. Amt.", 0.01));
                                            vInfoAmountTotal := vInfoAmountTotal + ROUND(TransInfoEntry."Info. Amt.", 0.01);
                                        END
                                        ELSE BEGIN
                                            PrintLineRemision(Tray, FALSE, TransInfoEntry.Information, ROUND(TransInfoEntry."Info. Amt." / 1.13, 0.01));
                                            vInfoAmountTotal := vInfoAmountTotal + ROUND(TransInfoEntry."Info. Amt." / 1.13, 0.01);
                                        END;
                                    END;
                                END;
                            END ELSE BEGIN
                                PrintUL.PrintTransInfoCode(TransInfoEntry, Tray, FALSE);
                            END;
                            LineCountRemision := LineCountRemision + 1;
                        END;
                    END;

                    totalCustItemDisc := totalCustItemDisc + SalesEntry."Infocode Discount";

                    IF NOT IsInvoice THEN BEGIN
                        DSTR1 := '#L## #L#################################';

                        Value[1] := POSFunctions.FormatQty(-SalesEntry.Quantity);
                        Value[2] := ItemName;

                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        DSTR1 := '                        #R#### #R#######';
                        IF (Item."No." = vProductoTelefonica1) OR (Item."No." = vProductoTelefonica2)
                        OR (Item."No." = vProductoTelefonica3) OR (Item."No." = vProductoTelefonica4) THEN
                            Value[1] := FORMAT(ROUND(ROUND(SalesEntry.Price / 1.18, 0.0001) + ROUND(ROUND(SalesEntry.Price / 1.18, 0.0001) * 0.13, 0.0001), 0.0001))
                        ELSE
                            Value[1] := POSFunctions.FormatAmount(SalesEntry.Price);
                        IF NOT Transaction."Sale Is Return Sale" THEN BEGIN
                            IF SalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF (Item."No." = vProductoTelefonica1) OR (Item."No." = vProductoTelefonica2)
                                OR (Item."No." = vProductoTelefonica3) OR (Item."No." = vProductoTelefonica4) THEN
                                    Value[2] := POSFunctions.FormatAmount(-((SalesEntry.Price * SalesEntry.Quantity) + vCESC)) + TextGravado
                                ELSE
                                    Value[2] := POSFunctions.FormatAmount(-(SalesEntry.Price * SalesEntry.Quantity)) + TextGravado;
                                TotalVentG += ABS(SalesEntry."Net Amount" + SalesEntry."VAT Amount");
                            END
                            ELSE BEGIN
                                IF SalesEntry."VAT Amount" = 0 THEN BEGIN
                                    Value[2] := POSFunctions.FormatAmount(-(SalesEntry.Price * SalesEntry.Quantity)) + TextExento;
                                    TotalVentE += ABS(SalesEntry."Net Amount" + SalesEntry."VAT Amount");
                                    /*Value[2] := POSFunctions.FormatAmount(-(SalesEntry.Price * SalesEntry.Quantity)) +
                                    TextNSujeto;
                                    TotalNoSuj += ABS(SalesEntry."Net Amount" + SalesEntry."VAT Amount");*/
                                END;
                            END;
                        END
                        ELSE BEGIN
                            IF SalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF (Item."No." = vProductoTelefonica1) OR (Item."No." = vProductoTelefonica2)
                                OR (Item."No." = vProductoTelefonica3) OR (Item."No." = vProductoTelefonica4) THEN
                                    Value[2] := POSFunctions.FormatAmount(-((SalesEntry.Price * SalesEntry.Quantity) - vCESC)) + TextGravado
                                ELSE
                                    Value[2] := POSFunctions.FormatAmount(-(SalesEntry.Price * SalesEntry.Quantity)) + TextGravado;
                                TotalVentG += ABS(SalesEntry."Net Amount" + SalesEntry."VAT Amount");
                            END
                            ELSE BEGIN
                                IF SalesEntry."VAT Amount" = 0 THEN BEGIN
                                    Value[2] := POSFunctions.FormatAmount(-(SalesEntry.Price * SalesEntry.Quantity)) + TextExento;
                                    TotalVentE += ABS(SalesEntry."Net Amount" + SalesEntry."VAT Amount");
                                    /*Value[2] := POSFunctions.FormatAmount(-(SalesEntry.Price * SalesEntry.Quantity)) +
                                    TextNSujeto;
                                    TotalNoSuj += ABS(SalesEntry."Net Amount" + SalesEntry."VAT Amount");*/
                                END;
                            END;
                        END;

                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                        IF SalesEntry."Variant Code" <> '' THEN BEGIN
                            DSTR1 := '#L####################';
                            Value[1] := SalesEntry."Variant Code";
                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        END;
                        IF (SalesEntry."Discount Amount" <> 0) OR
                           (SalesEntry."Discount Amt. For Printing" <> 0) OR
                           (SalesEntry."Line Discount" <> 0) OR
                           (SalesEntry."Coupon Amt. For Printing" <> 0) THEN BEGIN
                            DSTR1 := '        #L#################### #R#######';
                            IF ((SalesEntry."Periodic Discount" <> 0) OR
                               (SalesEntry."Discount Amt. For Printing" <> 0)) AND
                               (SalesEntry."Customer Discount" = 0) THEN BEGIN
                                IF (SalesEntry."Periodic Disc. Type" <> SalesEntry."Periodic Disc. Type"::" ") THEN BEGIN
                                    IF SalesEntry."Periodic Disc. Type" = SalesEntry."Periodic Disc. Type"::"Mix&Match" THEN
                                        PrintUL.BufferDiscount(
                                          PerDiscOffArr, PerDiscOffAmtArr, PerDiscOffArrCount,
                                          SalesEntry."Periodic Disc. Group", SalesEntry."Discount Amt. For Printing")
                                    ELSE
                                        PrintUL.BufferDiscount(
                                          PerDiscOffArr, PerDiscOffAmtArr, PerDiscOffArrCount,
                                          SalesEntry."Periodic Disc. Group", SalesEntry."Periodic Discount");
                                    IF PeriodicDiscount.GET(SalesEntry."Periodic Disc. Group") THEN
                                        discText := PeriodicDiscount.Description
                                    ELSE
                                        discText := FORMAT(PeriodicDiscount.Type);
                                END;

                                IF SalesEntry."Discount Amt. For Printing" <> 0 THEN BEGIN
                                    Value[1] := discText;

                                    IF Transaction."Sale Is Return Sale" THEN BEGIN
                                        Value[2] := POSFunctions.FormatAmount(ROUND(SalesEntry."Discount Amt. For Printing", 0.01));
                                    END ELSE BEGIN
                                        Value[2] := POSFunctions.FormatAmount(ROUND(-SalesEntry."Discount Amt. For Printing", 0.01));
                                    END;
                                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                END
                                ELSE
                                    IF SalesEntry."Periodic Disc. Type" = SalesEntry."Periodic Disc. Type"::"Disc. Offer" THEN BEGIN
                                        Value[1] := discText;
                                        Value[2] := POSFunctions.FormatAmount(-SalesEntry."Periodic Discount");
                                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                    END;
                            END
                            //*************************************************************************
                            //Este es para que si no es Periodic Discount, muestre el descuento por medio de pago
                            ELSE
                                IF SalesEntry."Discount Amount" <> 0 THEN BEGIN
                                    Value[1] := PeriodicDiscountInfoTEMP.Description;
                                    Value[2] := POSFunctions.FormatAmount(-SalesEntry."Discount Amount");
                                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                END;
                            //************************************************************************************
                            IF SalesEntry."Line Discount" <> 0 THEN BEGIN
                                Value[1] := Text084;
                                Value[2] := POSFunctions.FormatAmount(-SalesEntry."Line Discount");
                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;

                            IF SalesEntry."Coupon Amt. For Printing" <> 0 THEN BEGIN
                                Value[1] := Text165;
                                Value[2] := POSFunctions.FormatAmount(-SalesEntry."Coupon Amt. For Printing");
                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;

                        END;
                        totalCustItemDisc := totalCustItemDisc + SalesEntry."Infocode Discount";
                        Descuento += SalesEntry."Discount Amount";

                    END
                    ELSE
                        IF IsInvoice THEN BEGIN
                            //cuento la cantidad de lineas en el formato de facturas.
                            //SODICO FACTURA
                            CantLinFact += 1;
                            RetailSetup.GET();
                            Value[1] := '';
                            Value[2] := '';
                            Value[3] := '';
                            Value[4] := '';
                            Value[5] := '';
                            Value[6] := '';
                            Value[7] := '';

                            rVATPostingSetup.RESET;
                            rVATPostingSetup.SETRANGE(rVATPostingSetup."VAT Bus. Posting Group", SalesEntry."VAT Bus. Posting Group");
                            rVATPostingSetup.SETRANGE(rVATPostingSetup."VAT Prod. Posting Group", SalesEntry."VAT Code");
                            IF rVATPostingSetup.FINDFIRST THEN
                                Impuesto := rVATPostingSetup."VAT %";
                            //impuesto gravado, se dejo una sola linea, con la cantidad, descripción, precio unitario y ventas gravadas
                            IF SalesEntry."VAT Amount" <> 0 THEN BEGIN

                                IF true THEN BEGIN
                                    DSTR1 := '      #L###  #L#########################    #R#####  #R####                     #R######';
                                END;

                                IF Transaction."Sale Is Return Sale" AND
                                (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                                    Value[1] := POSFunctions.FormatQty(SalesEntry.Quantity);
                                END
                                ELSE BEGIN
                                    IF true THEN
                                        Value[1] := POSFunctions.FormatQty(-SalesEntry.Quantity)
                                    ELSE
                                        Value[1] := POSFunctions.FormatQty(-SalesEntry.Quantity);
                                END;
                                Value[2] := Item.Description;
                                IF true THEN BEGIN
                                    IF Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Credito Fiscal" THEN BEGIN
                                        IF (Item."No." = vProductoTelefonica1) OR (Item."No." = vProductoTelefonica2)
                                        OR (Item."No." = vProductoTelefonica3) OR (Item."No." = vProductoTelefonica4) THEN BEGIN
                                            Precio := ROUND(SalesEntry.Price / (1 + (Impuesto / 100)), 0.0001);
                                            Value[3] := FORMAT(Precio);
                                            PosPunto := STRPOS(Value[3], '.');
                                            IF (PosPunto = 0) THEN
                                                Value[3] := Value[3] + '.00';
                                            Value[5] := POSFunctions.FormatAmount((ROUND((SalesEntry.Price / (1 + (Impuesto / 100))), 0.0001)) * ABS(SalesEntry.Quantity)) + 'G';
                                        END
                                        ELSE BEGIN
                                            Precio := ROUND((SalesEntry.Price / (1 + (Impuesto / 100))), 0.0001);
                                            Value[3] := FORMAT(Precio);
                                            PosPunto := STRPOS(Value[3], '.');
                                            IF (PosPunto = 0) THEN
                                                Value[3] := Value[3] + '.00';
                                            Value[5] := POSFunctions.FormatAmount((ROUND((SalesEntry.Price / (1 + (Impuesto / 100))), 0.0001)) * ABS(SalesEntry.Quantity)) + 'G';
                                        END;
                                    END
                                    ELSE
                                        IF Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final" THEN BEGIN
                                            IF (Item."No." = vProductoTelefonica1) OR (Item."No." = vProductoTelefonica2)
                                            OR (Item."No." = vProductoTelefonica3) OR (Item."No." = vProductoTelefonica4) THEN BEGIN
                                                Value[3] := FORMAT(ROUND(ROUND(SalesEntry.Price / 1.18, 0.0001) + ROUND(ROUND(SalesEntry.Price / 1.18, 0.0001) * 0.13, 0.0001), 0.0001));
                                                Value[5] := POSFunctions.FormatAmount(ROUND(-(SalesEntry.Price * SalesEntry.Quantity) - vCESC)) + 'G';
                                            END
                                            ELSE BEGIN
                                                Value[3] := POSFunctions.FormatAmount(ABS(SalesEntry.Price));
                                                Value[5] := POSFunctions.FormatAmount(ROUND(-(SalesEntry.Price * SalesEntry.Quantity))) + 'G';
                                            END;
                                        END
                                        ELSE
                                            IF Transaction."Sale Is Return Sale" AND
                                       (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                                                IF (Item."No." = vProductoTelefonica1) OR (Item."No." = vProductoTelefonica2)
                                                 OR (Item."No." = vProductoTelefonica3) OR (Item."No." = vProductoTelefonica4) THEN BEGIN
                                                    Precio := ROUND((SalesEntry.Price / (1 + (Impuesto / 100))), 0.0001);
                                                    Value[3] := FORMAT(Precio);
                                                    PosPunto := STRPOS(Value[3], '.');
                                                    IF (PosPunto = 0) THEN
                                                        Value[3] := Value[3] + '.00';
                                                    Value[5] := POSFunctions.FormatAmount((ROUND((SalesEntry.Price / (1 + (Impuesto / 100))), 0.0001)) * ABS(SalesEntry.Quantity)) + 'G';
                                                END
                                                ELSE BEGIN
                                                    Precio := ROUND((SalesEntry.Price / (1 + (Impuesto / 100))), 0.0001);
                                                    Value[3] := FORMAT(Precio);
                                                    PosPunto := STRPOS(Value[3], '.');
                                                    IF (PosPunto = 0) THEN
                                                        Value[3] := Value[3] + '.00';
                                                    Value[5] := POSFunctions.FormatAmount((ROUND((SalesEntry.Price / (1 + (Impuesto / 100))), 0.0001)) * ABS(SalesEntry.Quantity)) + 'G';
                                                END;
                                            END
                                            ELSE
                                                IF Transaction."Sale Is Return Sale" AND
                                           (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN

                                                    Value[3] := POSFunctions.FormatAmount(-(SalesEntry."Net Amount") / ABS(SalesEntry.Quantity));

                                                    Value[5] := POSFunctions.FormatAmount(-(SalesEntry.Price * SalesEntry.Quantity)) + 'G';
                                                END
                                END
                                ELSE BEGIN
                                    IF Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Credito Fiscal" THEN BEGIN
                                        Precio := ROUND((SalesEntry.Price / (1 + (Impuesto / 100))), 0.01);

                                        Value[5] := FORMAT(Precio);
                                        PosPunto := STRPOS(Value[5], '.');
                                        IF (PosPunto = 0) THEN
                                            Value[5] := Value[5] + '.00000';

                                        Value[5] := POSFunctions.FormatAmount((ROUND((SalesEntry.Price / (1 + (Impuesto / 100))), 0.01))
                                                    * ABS(SalesEntry.Quantity));
                                    END
                                    ELSE
                                        IF Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final" THEN BEGIN
                                            Value[5] := POSFunctions.FormatAmount(-(SalesEntry."Net Amount" + SalesEntry."VAT Amount") / ABS(SalesEntry.Quantity));
                                            Value[6] := POSFunctions.FormatAmount(-(SalesEntry.Price * SalesEntry.Quantity));
                                        END
                                        ELSE
                                            IF Transaction."Sale Is Return Sale" AND
                                       (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                                                Value[5] := POSFunctions.FormatAmount((SalesEntry."Net Amount") / ABS(SalesEntry.Quantity));
                                                Value[6] := POSFunctions.FormatAmount(-(SalesEntry.Price * SalesEntry.Quantity));
                                            END
                                            ELSE
                                                IF Transaction."Sale Is Return Sale" AND
                                           (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                                                    Value[5] := POSFunctions.FormatAmount(-(SalesEntry."Net Amount") / ABS(SalesEntry.Quantity));
                                                    Value[6] := POSFunctions.FormatAmount(-(SalesEntry.Price * SalesEntry.Quantity));
                                                END

                                END;
                                //FASANI Para que solo imprima los resumenes, no el detalle
                                IF NOT (EsRemision) THEN
                                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                //Descuento impuesto gravado
                                IF (SalesEntry."Discount Amount" <> 0) OR
                                (SalesEntry."Discount Amt. For Printing" <> 0) OR
                                (SalesEntry."Line Discount" <> 0) OR
                                (SalesEntry."Coupon Amt. For Printing" <> 0) THEN BEGIN
                                    IF True then
                                        DSTR1 := '             #L#########################             #R####                     #R######'
                                    ELSE
                                        DSTR1 := '#L##################### #R#######';

                                    IF ((SalesEntry."Periodic Discount" <> 0) OR
                                    (SalesEntry."Discount Amt. For Printing" <> 0)) AND
                                    (SalesEntry."Customer Discount" = 0) THEN BEGIN
                                        IF (SalesEntry."Periodic Disc. Type" <> SalesEntry."Periodic Disc. Type"::" ") THEN BEGIN
                                            IF SalesEntry."Periodic Disc. Type" = SalesEntry."Periodic Disc. Type"::"Mix&Match" THEN
                                                PrintUL.BufferDiscount(PerDiscOffArr, PerDiscOffAmtArr, PerDiscOffArrCount, SalesEntry."Periodic Disc. Group", SalesEntry."Discount Amt. For Printing")
                                            ELSE
                                                PrintUL.BufferDiscount(PerDiscOffArr, PerDiscOffAmtArr, PerDiscOffArrCount, SalesEntry."Periodic Disc. Group", SalesEntry."Periodic Discount");
                                            IF PeriodicDiscount.GET(SalesEntry."Periodic Disc. Group") THEN
                                                discText := PeriodicDiscount.Description
                                            ELSE
                                                discText := FORMAT(PeriodicDiscount.Type);
                                        END;
                                        IF SalesEntry."Discount Amt. For Printing" <> 0 THEN BEGIN
                                            Value[1] := discText;
                                            IF Transaction."Sale Is Return Sale" THEN BEGIN
                                                IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                                                    Value[2] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Discount Amt. For Printing" / (1 + (Impuesto / 100))), 0.01)));
                                                    Value[3] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Discount Amt. For Printing" / (1 + (Impuesto / 100))), 0.01)));
                                                END
                                                ELSE BEGIN
                                                    Value[2] := POSFunctions.FormatAmount(SalesEntry."Discount Amt. For Printing");
                                                    Value[3] := POSFunctions.FormatAmount(SalesEntry."Discount Amt. For Printing");
                                                END;
                                            END
                                            ELSE BEGIN
                                                //Descuento Multibuy
                                                IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                                                    Value[2] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Discount Amt. For Printing"), 0.01)));
                                                    Value[3] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Discount Amt. For Printing"), 0.01)));
                                                END
                                                ELSE BEGIN
                                                    Value[2] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Discount Amt. For Printing" / (1 + (Impuesto / 100))), 0.01)));
                                                    Value[3] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Discount Amt. For Printing" / (1 + (Impuesto / 100))), 0.01)));
                                                END;
                                            END;
                                            IF NOT (EsRemision) THEN
                                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                            //LineCount aumentado al imprimir linea de descuento
                                            LineCount := LineCount + 1;
                                        END
                                        ELSE
                                            IF SalesEntry."Periodic Disc. Type" = SalesEntry."Periodic Disc. Type"::"Disc. Offer" THEN BEGIN
                                                Value[1] := discText;
                                                IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Credito Fiscal") THEN BEGIN
                                                    Value[2] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Periodic Discount" / (1 + (Impuesto / 100))), 0.01)));
                                                    Value[3] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Periodic Discount" / (1 + (Impuesto / 100))), 0.01)));
                                                END
                                                ELSE
                                                    IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                                                        Value[2] := POSFunctions.FormatAmount((ROUND((SalesEntry."Periodic Discount" / (1 + (Impuesto / 100))), 0.01)));
                                                        Value[3] := POSFunctions.FormatAmount((ROUND((SalesEntry."Periodic Discount" / (1 + (Impuesto / 100))), 0.01)));
                                                    END
                                                    ELSE BEGIN
                                                        Value[2] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Periodic Discount"), 0.00001)));
                                                        Value[3] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Periodic Discount"), 0.00001)));
                                                    END;
                                                IF NOT (EsRemision) THEN
                                                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                                //LineCount aumentado al imprimir linea de descuento
                                                LineCount := LineCount + 1;
                                            END;
                                    END;
                                    IF SalesEntry."Line Discount" <> 0 THEN BEGIN
                                        Value[1] := Text084;
                                        IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Credito Fiscal") THEN BEGIN
                                            Value[2] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Line Discount" / (1 + (Impuesto / 100))), 0.01)));
                                            Value[3] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Line Discount" / (1 + (Impuesto / 100))), 0.01)));
                                        END
                                        ELSE BEGIN
                                            Value[2] := POSFunctions.FormatAmount(-SalesEntry."Line Discount");
                                            Value[3] := POSFunctions.FormatAmount(-SalesEntry."Line Discount");
                                        END;
                                        IF NOT (EsRemision) THEN
                                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                        //LineCount aumentado al imprimir linea de descuento
                                        LineCount := LineCount + 1;
                                    END;
                                    IF SalesEntry."Coupon Amt. For Printing" <> 0 THEN BEGIN
                                        Value[1] := Text165;
                                        IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Credito Fiscal") THEN BEGIN
                                            Value[2] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Coupon Amt. For Printing" / (1 + (Impuesto / 100))), 0.01)));
                                            Value[3] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Coupon Amt. For Printing" / (1 + (Impuesto / 100))), 0.01)));
                                        END
                                        ELSE BEGIN
                                            Value[2] := POSFunctions.FormatAmount(-SalesEntry."Coupon Amt. For Printing");
                                            Value[3] := POSFunctions.FormatAmount(-SalesEntry."Coupon Amt. For Printing");
                                        END;
                                        IF NOT (EsRemision) THEN
                                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                        //LineCount aumentado al imprimir linea de descuento
                                        LineCount := LineCount + 1;
                                    END;
                                END;
                                //Descuento de cliente
                                IF (SalesEntry."Customer Discount" <> 0) THEN BEGIN
                                    DSTR1 := '             #L#########################             #R####                     #R######';
                                    IF (SalesEntry."Periodic Disc. Type" = SalesEntry."Periodic Disc. Type"::" ") THEN BEGIN
                                        Value[1] := Text085;
                                        IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                                            Value[2] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Customer Discount"), 0.01)));
                                        END
                                        ELSE BEGIN
                                            Value[2] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Customer Discount" / (1 + (Impuesto / 100))), 0.01)));
                                        END;
                                        Value[3] := Value[2];

                                        IF NOT (EsRemision) THEN
                                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                        LineCount := LineCount + 1;
                                    END;
                                END;

                                IF Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Credito Fiscal" THEN BEGIN
                                    IF EsRemision THEN BEGIN
                                        TotalVentG += (SalesEntry."Net Amount");
                                        TotalIVA += (SalesEntry."VAT Amount");
                                    END ELSE BEGIN
                                        IF (Item."No." = vProductoTelefonica1) OR (Item."No." = vProductoTelefonica2)
                                        OR (Item."No." = vProductoTelefonica3) OR (Item."No." = vProductoTelefonica4) THEN BEGIN
                                            TotalVentG += ABS(SalesEntry."Net Amount");
                                            TotalIVA += ABS(SalesEntry."VAT Amount" + vCESC);
                                        END
                                        ELSE BEGIN
                                            TotalVentG += ABS(SalesEntry."Net Amount");
                                            TotalIVA += ABS(SalesEntry."VAT Amount");
                                        END;
                                    END;
                                END
                                ELSE
                                    IF Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final" THEN BEGIN
                                        IF EsRemision THEN BEGIN
                                            TotalVentG += (SalesEntry."Net Amount") + (SalesEntry."VAT Amount");
                                        END ELSE BEGIN
                                            IF (Item."No." = vProductoTelefonica1) OR (Item."No." = vProductoTelefonica2)
                                            OR (Item."No." = vProductoTelefonica3) OR (Item."No." = vProductoTelefonica4) THEN
                                                TotalVentG += ABS(SalesEntry."Net Amount") + ABS(SalesEntry."VAT Amount")
                                            ELSE
                                                TotalVentG += ABS(SalesEntry."Net Amount") + ABS(SalesEntry."VAT Amount");
                                        END;
                                    END
                                    ELSE
                                        IF Transaction."Sale Is Return Sale" AND
                                   (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                                            IF EsRemision THEN BEGIN
                                                TotalVentG += (SalesEntry."Net Amount");
                                                TotalIVA += (SalesEntry."VAT Amount");
                                            END ELSE BEGIN
                                                IF (Item."No." = vProductoTelefonica1) OR (Item."No." = vProductoTelefonica2)
                                                OR (Item."No." = vProductoTelefonica3) OR (Item."No." = vProductoTelefonica4) THEN BEGIN
                                                    TotalVentG += ABS(SalesEntry."Net Amount");
                                                    TotalIVA += ABS(SalesEntry."VAT Amount" - vCESC);
                                                END
                                                ELSE BEGIN
                                                    TotalVentG += ABS(SalesEntry."Net Amount");
                                                    TotalIVA += ABS(SalesEntry."VAT Amount");
                                                END;
                                            END;
                                        END
                                        ELSE
                                            IF Transaction."Sale Is Return Sale" AND
                                       (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                                                IF EsRemision THEN
                                                    TotalVentG += (SalesEntry.Price)
                                                ELSE
                                                    TotalVentG += ABS(SalesEntry.Price);
                                            END
                            END
                            //impuesto exento, se dejo una sola linea, con la cantidad, descripción, precio unitario y ventas gravadas
                            ELSE
                                IF SalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF True then begin
                                        DSTR1 := '      #L###  #L#########################    #R#####  #R####          #R######           ';
                                    END;

                                    if true then begin
                                        IF Transaction."Sale Is Return Sale" AND
                                        (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                                            Value[1] := POSFunctions.FormatQty(SalesEntry.Quantity);
                                        END
                                        ELSE BEGIN
                                            Value[1] := POSFunctions.FormatQty(-SalesEntry.Quantity);
                                        END;
                                        Value[2] := Item.Description;

                                        IF (Transaction."Sale Is Return Sale" AND
                                        (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito"))
                                        OR ((Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Credito Fiscal")) THEN BEGIN
                                            Precio := ROUND(SalesEntry."Net Price", 0.01);
                                            Value[3] := FORMAT(Precio);
                                            PosPunto := STRPOS(Value[3], '.');
                                            IF (PosPunto = 0) THEN
                                                Value[3] := Value[3] + '.00';
                                        END
                                        ELSE BEGIN
                                            Value[3] := POSFunctions.FormatAmount(SalesEntry."Net Price");
                                        END;
                                        IF Transaction."Sale Is Return Sale" AND
                                        (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                                            Value[5] := POSFunctions.FormatAmount((SalesEntry.Price * SalesEntry.Quantity)) + 'E';
                                        END
                                        ELSE BEGIN
                                            Value[5] := POSFunctions.FormatAmount(-(SalesEntry.Price * SalesEntry.Quantity)) + 'E';
                                        END;
                                    END
                                    ELSE BEGIN
                                        IF Transaction."Sale Is Return Sale" AND
                                        (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                                            Value[3] := POSFunctions.FormatQty(SalesEntry.Quantity);
                                        END
                                        ELSE BEGIN
                                            Value[5] := POSFunctions.FormatQty(-SalesEntry.Quantity);
                                        END;
                                        Value[5] := '$' + POSFunctions.FormatAmount(SalesEntry."Net Price");
                                        IF Transaction."Sale Is Return Sale" AND
                                        (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                                            Value[6] := '$' + POSFunctions.FormatAmount(-(SalesEntry.Price * SalesEntry.Quantity));
                                        END
                                        ELSE BEGIN
                                            Value[6] := '$' + POSFunctions.FormatAmount(-(SalesEntry.Price * SalesEntry.Quantity));
                                        END;
                                    END;
                                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                    //Descuento impuesto exento
                                    IF (SalesEntry."Discount Amount" <> 0) OR
                                    (SalesEntry."Discount Amt. For Printing" <> 0) OR
                                    (SalesEntry."Line Discount" <> 0) OR
                                    (SalesEntry."Coupon Amt. For Printing" <> 0) THEN BEGIN
                                        IF True then
                                            DSTR1 := '             #L#########################             #R####        #R######            '
                                        ELSE
                                            DSTR1 := '     #L#####################                                                   #R#######';
                                        IF ((SalesEntry."Periodic Discount" <> 0) OR
                                        (SalesEntry."Discount Amt. For Printing" <> 0)) AND
                                        (SalesEntry."Customer Discount" = 0) THEN BEGIN
                                            IF (SalesEntry."Periodic Disc. Type" <> SalesEntry."Periodic Disc. Type"::" ") THEN BEGIN
                                                IF SalesEntry."Periodic Disc. Type" = SalesEntry."Periodic Disc. Type"::"Mix&Match" THEN
                                                    PrintUL.BufferDiscount(PerDiscOffArr, PerDiscOffAmtArr, PerDiscOffArrCount, SalesEntry."Periodic Disc. Group", SalesEntry."Discount Amt. For Printing")
                                                ELSE
                                                    PrintUL.BufferDiscount(PerDiscOffArr, PerDiscOffAmtArr, PerDiscOffArrCount, SalesEntry."Periodic Disc. Group", SalesEntry."Periodic Discount");
                                                IF PeriodicDiscount.GET(SalesEntry."Periodic Disc. Group") THEN
                                                    discText := PeriodicDiscount.Description
                                                ELSE
                                                    discText := FORMAT(PeriodicDiscount.Type);
                                            END;

                                            IF SalesEntry."Discount Amt. For Printing" <> 0 THEN BEGIN
                                                Value[1] := discText;
                                                IF Transaction."Sale Is Return Sale" THEN BEGIN
                                                    Value[2] := POSFunctions.FormatAmount(SalesEntry."Discount Amt. For Printing");
                                                    Value[3] := POSFunctions.FormatAmount(SalesEntry."Discount Amt. For Printing");
                                                END ELSE BEGIN
                                                    Value[2] := POSFunctions.FormatAmount(-SalesEntry."Discount Amt. For Printing");
                                                    Value[3] := POSFunctions.FormatAmount(-SalesEntry."Discount Amt. For Printing");
                                                END;
                                                IF NOT (EsRemision) THEN
                                                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                                //LineCount aumentado al imprimir linea de descuento
                                                LineCount := LineCount + 1;
                                            END
                                            ELSE
                                                IF SalesEntry."Periodic Disc. Type" = SalesEntry."Periodic Disc. Type"::"Disc. Offer" THEN BEGIN
                                                    Value[1] := discText;
                                                    Value[2] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Periodic Discount" / (1 + (Impuesto / 100))), 0.01)));
                                                    Value[3] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Periodic Discount" / (1 + (Impuesto / 100))), 0.01)));
                                                    IF NOT (EsRemision) THEN
                                                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                                    //LineCount aumentado al imprimir linea de descuento
                                                    LineCount := LineCount + 1;
                                                END;
                                        END;

                                        IF SalesEntry."Line Discount" <> 0 THEN BEGIN
                                            Value[1] := Text084;
                                            Value[2] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Line Discount" / (1 + (Impuesto / 100))), 0.01)));
                                            Value[3] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Line Discount" / (1 + (Impuesto / 100))), 0.01)));
                                            IF NOT (EsRemision) THEN
                                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                            //LineCount aumentado al imprimir linea de descuento
                                            LineCount := LineCount + 1;
                                        END;

                                        IF SalesEntry."Coupon Amt. For Printing" <> 0 THEN BEGIN
                                            Value[1] := Text165;
                                            Value[2] := POSFunctions.FormatAmount(-SalesEntry."Coupon Amt. For Printing");
                                            Value[3] := POSFunctions.FormatAmount(-SalesEntry."Coupon Amt. For Printing");
                                            IF NOT (EsRemision) THEN
                                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                            //LineCount aumentado al imprimir linea de descuento
                                            LineCount := LineCount + 1;
                                        END;
                                    END;

                                    //Descuento de cliente
                                    IF (SalesEntry."Customer Discount" <> 0) THEN BEGIN
                                        DSTR1 := '             #L#########################             #R####                     #R######';
                                        IF (SalesEntry."Periodic Disc. Type" = SalesEntry."Periodic Disc. Type"::" ") THEN BEGIN
                                            Value[1] := Text085;
                                            IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                                                Value[2] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Customer Discount"), 0.01)));
                                            END
                                            ELSE BEGIN
                                                Value[2] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Customer Discount" / (1 + (Impuesto / 100))), 0.01)));
                                            END;
                                            Value[3] := Value[2];
                                            IF NOT (EsRemision) THEN
                                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                            LineCount := LineCount + 1;
                                        END;
                                    END;
                                    TotalVentE += ABS(SalesEntry."Net Amount");
                                END
                                ELSE
                                    IF SalesEntry."VAT Amount" = 0 THEN BEGIN
                                        if true then
                                            DSTR1 := '#L#######  #L##################################'
                                        ELSE
                                            DSTR1 := '   #L############ #L###############    #L##    #L#####   #L#######';

                                        Value[1] := Item."No.";
                                        Value[2] := Item.Description;

                                        if true then begin
                                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                            DSTR1 := '#L#####   #R#######                #R#######';
                                        END;

                                        IF true then begin
                                            IF Transaction."Sale Is Return Sale" AND
                                            (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN
                                                Value[1] := POSFunctions.FormatQty(SalesEntry.Quantity)
                                            ELSE
                                                Value[1] := POSFunctions.FormatQty(-SalesEntry.Quantity);
                                            SubtotalLinea := ROUND(SalesEntry.Price * SalesEntry.Quantity, 0.01);
                                            Precio := ROUND((SubtotalLinea / SalesEntry.Quantity), 0.01);

                                            Value[2] := FORMAT(Precio);
                                            PosPunto := STRPOS(Value[2], '.');
                                            IF (PosPunto = 0) THEN
                                                Value[2] := Value[2] + '.00000';
                                            IF Transaction."Sale Is Return Sale" AND
                                            (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                                                Value[3] := POSFunctions.FormatAmount(-(SalesEntry.Price * SalesEntry.Quantity)) + 'G';
                                            END
                                            ELSE BEGIN
                                                Value[3] := POSFunctions.FormatAmount(-(SalesEntry.Price * SalesEntry.Quantity)) + 'G';
                                            END;
                                        END
                                        ELSE BEGIN
                                            IF Transaction."Sale Is Return Sale" AND
                                            (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                                                Value[3] := POSFunctions.FormatQty(SalesEntry.Quantity);
                                            END
                                            ELSE BEGIN
                                                Value[3] := POSFunctions.FormatQty(-SalesEntry.Quantity);
                                            END;

                                            Value[4] := '$' + POSFunctions.FormatAmount(SalesEntry."Net Price");
                                            IF Transaction."Sale Is Return Sale" AND
                                            (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                                                Value[5] := '$' + POSFunctions.FormatAmount(-(SalesEntry.Price * SalesEntry.Quantity));
                                            END
                                            ELSE BEGIN
                                                Value[5] := '$' + POSFunctions.FormatAmount(-(SalesEntry.Price * SalesEntry.Quantity));
                                            END;
                                        END;
                                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                        IF (SalesEntry."Discount Amount" <> 0) OR
                                        (SalesEntry."Discount Amt. For Printing" <> 0) OR
                                        (SalesEntry."Line Discount" <> 0) OR
                                        (SalesEntry."Coupon Amt. For Printing" <> 0) THEN BEGIN
                                            IF True then
                                                DSTR1 := '             #L#########################             #R####                    #R######'
                                            ELSE
                                                DSTR1 := '     #L#####################                                                   #R#######';

                                            IF ((SalesEntry."Periodic Discount" <> 0) OR
                                            (SalesEntry."Discount Amt. For Printing" <> 0)) AND
                                            (SalesEntry."Customer Discount" = 0) THEN BEGIN
                                                IF (SalesEntry."Periodic Disc. Type" <> SalesEntry."Periodic Disc. Type"::" ") THEN BEGIN
                                                    IF SalesEntry."Periodic Disc. Type" = SalesEntry."Periodic Disc. Type"::"Mix&Match" THEN
                                                        PrintUL.BufferDiscount(PerDiscOffArr, PerDiscOffAmtArr, PerDiscOffArrCount, SalesEntry."Periodic Disc. Group", SalesEntry."Discount Amt. For Printing")
                                                    ELSE
                                                        PrintUL.BufferDiscount(PerDiscOffArr, PerDiscOffAmtArr, PerDiscOffArrCount, SalesEntry."Periodic Disc. Group", SalesEntry."Periodic Discount");
                                                    IF PeriodicDiscount.GET(SalesEntry."Periodic Disc. Group") THEN
                                                        discText := PeriodicDiscount.Description
                                                    ELSE
                                                        discText := FORMAT(PeriodicDiscount.Type);
                                                END;

                                                IF SalesEntry."Discount Amt. For Printing" <> 0 THEN BEGIN
                                                    Value[1] := discText;
                                                    IF Transaction."Sale Is Return Sale" THEN BEGIN
                                                        Value[2] := POSFunctions.FormatAmount(SalesEntry."Discount Amt. For Printing");
                                                    END
                                                    ELSE BEGIN
                                                        Value[2] := POSFunctions.FormatAmount(-SalesEntry."Discount Amt. For Printing");
                                                    END;
                                                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                                END
                                                ELSE
                                                    IF SalesEntry."Periodic Disc. Type" = SalesEntry."Periodic Disc. Type"::"Disc. Offer" THEN BEGIN
                                                        Value[1] := discText;
                                                        Value[2] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Periodic Discount" / (1 + (Impuesto / 100))), 0.01)));
                                                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                                    END;
                                            END;

                                            IF SalesEntry."Line Discount" <> 0 THEN BEGIN
                                                Value[1] := Text084;
                                                Value[2] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Line Discount" / (1 + (Impuesto / 100))), 0.01)));
                                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                            END;

                                            IF SalesEntry."Coupon Amt. For Printing" <> 0 THEN BEGIN
                                                Value[1] := Text165;
                                                Value[2] := POSFunctions.FormatAmount(-SalesEntry."Coupon Amt. For Printing");
                                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                            END;
                                        END;
                                        //Descuento de cliente
                                        IF (SalesEntry."Customer Discount" <> 0) THEN BEGIN
                                            DSTR1 := '             #L#########################             #R####                     #R######';
                                            IF (SalesEntry."Periodic Disc. Type" = SalesEntry."Periodic Disc. Type"::" ") THEN BEGIN
                                                Value[1] := Text085;
                                                IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                                                    Value[2] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Customer Discount"), 0.01)));
                                                END
                                                ELSE BEGIN
                                                    Value[2] := POSFunctions.FormatAmount((ROUND(-(SalesEntry."Customer Discount" / (1 + (Impuesto / 100))), 0.01)));
                                                END;
                                                Value[3] := Value[2];
                                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                                LineCount := LineCount + 1;
                                            END;
                                        END;
                                        TotalNoSuj += ABS(SalesEntry."Net Amount");
                                    END;
                        END;
                    LineCount := LineCount + 1;

                    //JNEHEMIAS201022-
                    TransInfoEntry.RESET;
                    TransInfoEntry.SETRANGE(TransInfoEntry.Infocode, 'NRECETA');//28981
                    TransInfoEntry.SETRANGE(TransInfoEntry."Transaction No.", Transaction."Transaction No.");
                    TransInfoEntry.SETRANGE(TransInfoEntry."POS Terminal No.", Transaction."POS Terminal No.");
                    TransInfoEntry.SETRANGE(TransInfoEntry."Store No.", Transaction."Store No.");
                    TransInfoEntry.SETRANGE(TransInfoEntry."Line No.", SalesEntry."Line No.");
                    IF TransInfoEntry.FINDFIRST THEN
                        Nreceta := TransInfoEntry.Information;
                    IF Nreceta <> '' THEN BEGIN
                        DSTR1 := '             #L#########################             #R####';
                        Value[1] := TextReceta + ' ' + Nreceta;
                        Value[2] := '';
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END;
                UNTIL SalesEntry.NEXT = 0;
            CLEAR(SalesEntry);
            SalesEntry.SETRANGE("Store No.", Transaction."Store No.");
            SalesEntry.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
            SalesEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
            IF OrderByDepartment THEN
                SalesEntry.SETCURRENTKEY("Item Category Code");
            IF SalesEntry.FIND('-') THEN
                REPEAT
                    IF Item.GET(SalesEntry."Item No.") THEN BEGIN
                        POSMenuLine.Parameter := Item."No.";
                        RequestID := 'GETITEMRECARGA';
                        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, POSMenuLine, Processed, MsgResult);
                        IF Processed THEN BEGIN
                            DSTR1 := '#C######################################';
                            Value[1] := '';
                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            DSTR1 := '    #L##############  #L################  ';
                            Value[1] := 'Trans. Operador:';
                            Processed := false;
                            IF NOT Transaction."Sale Is Return Sale" THEN begin
                                CLEAR(POSMenuLine);
                                POSMenuLine."Current-RECEIPT" := Transaction."Receipt No.";
                                RequestID := 'GETRECEIPTRECARGA';
                                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, POSMenuLine, Processed, MsgResult);
                                Processed := true;
                            end ELSE begin
                                CLEAR(POSMenuLine);
                                POSMenuLine."Current-RECEIPT" := Transaction."Retrieved from Receipt No.";
                                RequestID := 'GETRECEIPTRECARGA';
                                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, POSMenuLine, Processed, MsgResult);
                                Processed := true;
                            end;
                            IF Processed THEN BEGIN
                                Value[2] := POSMenuLine."Primary Key";
                                vTelefono := POSMenuLine."POS Action Message";
                                vTipoPaquete := POSMenuLine."Image URI";
                            END;
                        end;
                        IF vTipoPaquete <> '' THEN BEGIN
                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            DSTR1 := '    #L##############  #L################  ';
                            Value[1] := 'Tipo Paquete:';
                            Value[2] := vTipoPaquete;
                        END;
                        IF vTelefono <> '' THEN BEGIN
                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            DSTR1 := '    #L##############  #L################  ';
                            Value[1] := 'Telefono:';
                            Value[2] := vTelefono;
                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            LineCount := LineCount + 3;
                        END;
                    END;
                UNTIL SalesEntry.NEXT = 0;

            //Imprimir descuento tender type al final de las lineas de productos
            IF NOT IsInvoice THEN BEGIN
            END
            ELSE BEGIN
                PeriodicDiscountInfoTEMP.RESET;
                PeriodicDiscountInfoTEMP.SETCURRENTKEY(Status, Type);
                PeriodicDiscountInfoTEMP.SETRANGE("Offer Type", PeriodicDiscountInfoTEMP."Offer Type"::"Tender Type");
                NodeName[1] := 'Total Text';
                NodeName[2] := 'Total Amount';
                IF PeriodicDiscountInfoTEMP.FINDSET THEN BEGIN
                    //Imprimir Linea en blanco...
                    DSTR1 := COPYSTR('                     ', 1);
                    Value[1] := '';
                    IF NOT (EsRemision) THEN
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    LineCount := LineCount + 1;

                    TotalAmtForSummary := Subtotal;
                    REPEAT
                        IF (GenPosFunc."Print Disc/Cpn Info on Slip" =
                        GenPosFunc."Print Disc/Cpn Info on Slip"::"Detail for each line and Sub-total") AND
                        (PeriodicDiscountInfoTEMP.Description <> Text024) THEN
                            PeriodicDiscountInfoTEMP."Discount Amount Value" := 0;
                        IF PeriodicDiscountInfoTEMP."Discount Amount Value" <> 0 THEN BEGIN
                            DSTR1 := '             #L#########################            #R####                             ';
                            Value[1] := PeriodicDiscountInfoTEMP.Description;
                            IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Credito Fiscal") OR
                            (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                                Value[2] := POSFunctions.FormatAmount(ROUND(-PeriodicDiscountInfoTEMP."Discount Amount Value" / (1 + (Impuesto / 100)), 0.01));
                                Value[3] := POSFunctions.FormatAmount(ROUND(-PeriodicDiscountInfoTEMP."Discount Amount Value" / (1 + (Impuesto / 100)), 0.01));
                            END
                            ELSE BEGIN
                                Value[2] := POSFunctions.FormatAmount(-PeriodicDiscountInfoTEMP."Discount Amount Value");
                                Value[3] := POSFunctions.FormatAmount(-PeriodicDiscountInfoTEMP."Discount Amount Value");
                            END;
                            IF NOT (EsRemision) THEN
                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            PrintUL.AddPrintLine(800, 2, NodeName, Value, DSTR1, FALSE, FALSE, FALSE, FALSE, Tray);
                            TotalAmtForSummary := TotalAmtForSummary + PeriodicDiscountInfoTEMP."Discount Amount Value";
                        END;
                        LineCount := LineCount + 1;
                    UNTIL PeriodicDiscountInfoTEMP.NEXT = 0;
                END;
            END;

        END;

        LineCount := LineCount + PrintSPOSalesInfo(Transaction, Tray);
        //Separador despues de lineas de productos, se le quito a la factura (se agrego 2 espacios en blanco en cambio).
        IF NOT IsInvoice THEN BEGIN
            IF LineCount > 0 THEN
                PrintUL.PrintSeperator(Tray);
        END
        ELSE BEGIN
            // teniendo el numero de LineCount, se imprime el resto de lineas en blanco
            //para que las SUMA se impriman donde se debe
            IF (EsRemision) THEN
                LineCount := LineCountRemision + 2;
            FOR iContador := 1 TO (28 - LineCount) DO BEGIN
                DSTR1 := '     ';
                Value[1] := '';
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END;
        END;
        rPosTerminal.RESET;
        rPosTerminal.SETRANGE("Store No.", Transaction."Store No.");
        rPosTerminal.SETRANGE("No.", Transaction."POS Terminal No.");
        rPosTerminal.FINDFIRST;
        IF (Transaction."FSN No. Serie NCF" = rPosTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
            DSTR1 := COPYSTR('                                                  ', 1);
            Value[1] := '';
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;
        IF (Transaction."FSN No. Serie NCF" = rPosTerminal."FSN No. Serie Credito Fiscal") THEN BEGIN
            FOR iContador := 1 TO 1 DO BEGIN
                DSTR1 := '     ';
                Value[1] := '';
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END;
        END;

        //Lineas de factura totales
        IncExpEntry.SETRANGE("Store No.", Transaction."Store No.");
        IncExpEntry.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
        IncExpEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
        IF IncExpEntry.FIND('-') THEN
            vIncomeExpense := TRUE
        ELSE
            vIncomeExpense := FALSE;
        IF NOT IsInvoice AND (Transaction."FSN Document Type" in [Transaction."FSN Document Type"::Ticket, Transaction."FSN Document Type"::"Devolucion Factura"]) AND NOT vIncomeExpense THEN BEGIN
            DSTR1 := '#L################## #R#################';
            Value[1] := TextSubTotal;
            IF NOT Transaction."Sale Is Return Sale" THEN BEGIN
                IF (Item."No." = vProductoTelefonica1) OR (Item."No." = vProductoTelefonica2)
                OR (Item."No." = vProductoTelefonica3) OR (Item."No." = vProductoTelefonica4) THEN
                    Value[2] := '$' + POSFunctions.FormatAmount(-Transaction."Gross Amount" + Transaction."Total Discount" - vCESC)
                ELSE
                    Value[2] := '$' + POSFunctions.FormatAmount(-Transaction."Gross Amount" + Transaction."Total Discount" - vCESC);
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END
            ELSE
                IF Transaction."Sale Is Return Sale" AND
           (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                    Value[2] := '$' + POSFunctions.FormatAmount(-Transaction."Gross Amount" + Transaction."Total Discount");
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END
                ELSE BEGIN
                    IF (Item."No." = vProductoTelefonica1) OR (Item."No." = vProductoTelefonica2)
                    OR (Item."No." = vProductoTelefonica3) OR (Item."No." = vProductoTelefonica4) THEN
                        Value[2] := '(' + '$' + POSFunctions.FormatAmount(Transaction."Gross Amount" - Transaction."Total Discount" - vCESC) + ')'
                    ELSE
                        Value[2] := '(' + '$' + POSFunctions.FormatAmount(Transaction."Gross Amount" - Transaction."Total Discount" - vCESC) + ')';//CSRG15102013
                                                                                                                                                   //Value[2] := '(' + '$' + FORMAT(TotalVentG + TotalVentE + TotalNoSuj,0,'<Integer Thousand><Decimals,3>') + ')';
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
        END;
        CLEAR(Value);
        CLEAR(SalesEntry);
        SalesEntry.SETRANGE("Store No.", Transaction."Store No.");
        SalesEntry.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
        SalesEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
        IF OrderByDepartment THEN
            SalesEntry.SETCURRENTKEY("Item Category Code");
        IF SalesEntry.FIND('-') THEN
            REPEAT
                IF Item.GET(SalesEntry."Item No.") THEN BEGIN
                    IF (Item."No." = vProductoTelefonica1) OR (Item."No." = vProductoTelefonica2)
                    OR (Item."No." = vProductoTelefonica3) OR (Item."No." = vProductoTelefonica4) THEN BEGIN
                        IF NOT IsInvoice AND (Transaction."FSN Document Type" in [Transaction."FSN Document Type"::Ticket, Transaction."FSN Document Type"::"Devolucion Factura"]) AND NOT vIncomeExpense THEN BEGIN
                            DSTR1 := '#L################## #R#################';
                            Value[1] := 'Impuesto CESC:';
                            IF NOT Transaction."Sale Is Return Sale" THEN BEGIN
                                Value[2] := '$' + POSFunctions.FormatAmount(vCESC);
                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END
                            ELSE BEGIN
                                Value[2] := '(' + '$' + POSFunctions.FormatAmount(vCESC) + ')';
                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;
                        END;
                        CLEAR(Value);
                    END;
                END;
            UNTIL SalesEntry.NEXT = 0;
        IF NOT IsInvoice AND (Transaction."FSN Document Type" in [Transaction."FSN Document Type"::Ticket, Transaction."FSN Document Type"::"Devolucion Factura"]) AND NOT vIncomeExpense THEN BEGIN
            DSTR1 := '#L################          #R#########';
            IF Transaction."Total Discount" <> 0 THEN BEGIN
                Value[1] := Text043;
                Value[2] := POSFunctions.FormatAmount(-Transaction."Total Discount");
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
            END;
        END;
        CLEAR(Value);
        IF IsInvoice THEN BEGIN
            if true then
                DSTR1 := '             #L################   #R#######'
            ELSE
                DSTR1 := '                                                    #L################     #R#######';

            IF Transaction."Total Discount" <> 0 THEN BEGIN
                Value[1] := 'Total Disc:';
                IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN
                    Value[2] := '$' + POSFunctions.FormatAmount(-1 * (Transaction."Total Discount" / (1 + (Impuesto / 100))))
                ELSE
                    IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Credito Fiscal") THEN
                        Value[2] := '$' + POSFunctions.FormatAmount(-Transaction."Total Discount" / (1 + (Impuesto / 100)))
                    ELSE
                        Value[2] := '$' + POSFunctions.FormatAmount(-Transaction."Total Discount");

                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
            END;
        END;
        CLEAR(Value);
        IF NOT IsInvoice AND (Transaction."FSN Document Type" in [Transaction."FSN Document Type"::Ticket, Transaction."FSN Document Type"::"Devolucion Factura"]) AND NOT vIncomeExpense THEN BEGIN
            //Ventas Gravadas
            DSTR1 := '#L################## #R#################';
            Value[1] := TextTotVentasG;
            IF NOT Transaction."Sale Is Return Sale" THEN BEGIN
                Value[2] := '$' + FORMAT(TotalVentG, 0, '<Integer Thousand><Decimals,3>');
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END
            ELSE
                IF Transaction."Sale Is Return Sale" THEN BEGIN
                    Value[2] := '(' + '$' + FORMAT(TotalVentG, 0, '<Integer Thousand><Decimals,3>') + ')';
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
        END
        ELSE
            IF IsInvoice THEN BEGIN
                //SUMAS, mostras las sumas de ventas exentas y gravadas en una sola linea
                CLEAR(SalesEntry);
                SalesEntry.SETRANGE("Store No.", Transaction."Store No.");
                SalesEntry.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
                SalesEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
                IF OrderByDepartment THEN
                    SalesEntry.SETCURRENTKEY("Item Category Code");
                IF SalesEntry.FIND('-') THEN
                    REPEAT
                        IF Item.GET(SalesEntry."Item No.") THEN BEGIN
                            IF (Item."No." = vProductoTelefonica1) OR (Item."No." = vProductoTelefonica2)
                            OR (Item."No." = vProductoTelefonica3) OR (Item."No." = vProductoTelefonica4) THEN BEGIN
                                DSTR1 := '                                                                  #R######## #R########';
                                Value[1] := 'CESC:';
                                Value[2] := '$' + FORMAT(vCESC);
                                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;
                        END;
                    UNTIL SalesEntry.NEXT = 0;
                if true then
                    DSTR1 := '      #L######################################                    #R######## #R########';
                Value[1] := Store.Name;

                IF NOT Transaction."Sale Is Return Sale" THEN BEGIN
                    Value[2] := '$' + FORMAT(TotalVentE, 0, '<Integer Thousand><Decimals,3>');
                    IF (EsRemision) THEN BEGIN
                    END
                    ELSE BEGIN
                        Value[3] := '$' + FORMAT(TotalVentG, 0, '<Integer Thousand><Decimals,3>');
                    END;
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END
                ELSE
                    IF (Transaction."Sale Is Return Sale") AND
               (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                        Value[2] := '$' + FORMAT(TotalVentE, 0, '<Integer Thousand><Decimals,3>');
                        Value[3] := '$' + FORMAT(TotalVentG, 0, '<Integer Thousand><Decimals,3>');
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END
                    ELSE BEGIN
                        Value[3] := '(' + '$' + FORMAT(TotalVentG, 0, '<Integer Thousand><Decimals,3>') + ')';
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END;
            END;

        //TOTAL IVA PARA LAS FACTURAS DE CREDITO FISCAL
        //se agrega las ventas no sujetas para facturas de consumidor final
        IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Credito Fiscal") OR
        (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") OR
        (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
            IF IsInvoice THEN BEGIN
                IF True then
                    DSTR1 := '      #L######################################                               #R########'
                ELSE
                    DSTR1 := '                                                   #L################     #R#######';

                Value[1] := TextCaja + Transaction."POS Terminal No.";
                IF NOT Transaction."Sale Is Return Sale" AND (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                    Value[2] := '$' + FORMAT(TotalNoSuj, 0, '<Integer Thousand><Decimals,3>');
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END
                ELSE
                    IF NOT Transaction."Sale Is Return Sale" THEN BEGIN
                        IF (EsRemision) THEN BEGIN
                            IF Transaction."Customer No." = 'C000002' THEN
                                Value[2] := '$' + FORMAT(ROUND(-vInfoAmountTotal * 0.13, 0.01), 0, '<Integer Thousand><Decimals,3>')
                            ELSE
                                Value[2] := '$' + FORMAT(ROUND(-vInfoAmountTotal * 0.13, 0.01), 0, '<Integer Thousand><Decimals,3>');
                        END
                        ELSE BEGIN
                            Value[2] := '$' + FORMAT(TotalIVA, 0, '<Integer Thousand><Decimals,3>');
                        END;
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END
                    ELSE
                        IF (Transaction."Sale Is Return Sale") AND
                   ((Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito")) THEN BEGIN
                            Value[2] := '$' + FORMAT(TotalIVA, 0, '<Integer Thousand><Decimals,3>');
                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        END;
            END;
        END;
        //Sub-Total
        IF IsInvoice THEN BEGIN
            IF true then
                DSTR1 := '      #L######################################                               #R########'
            ELSE
                DSTR1 := '                                                    #L################     #R#######';
            SalesEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
            IF SalesEntry.FIND('-') THEN
                jContador := 1;
            REPEAT
                vAgregarSalesPersonNo := 0;
                FOR iContador := 1 TO 30 DO BEGIN
                    IF SalesEntry."Sales Staff" = vSalesPersonNo[iContador] THEN
                        vAgregarSalesPersonNo += 1;
                END;
                IF vAgregarSalesPersonNo = 0 THEN BEGIN
                    vSalesPersonNo[jContador] := SalesEntry."Sales Staff";
                    jContador += 1;
                    rStaff1.RESET;
                    rStaff1.SETRANGE(ID, SalesEntry."Sales Staff");
                    IF rStaff1.FIND('-') THEN BEGIN
                        rSalesPerson.RESET;
                        rSalesPerson.SETRANGE(Code, rStaff1."Sales Person");
                        IF rSalesPerson.FIND('-') THEN
                            REPEAT
                                vVendedor := vVendedor + rStaff1.ID + ' ';
                            UNTIL rSalesPerson.NEXT = 0;
                    END;
                END;
            UNTIL SalesEntry.NEXT = 0;
            Value[1] := 'Cajero: ' + Transaction."Staff ID" + '  Vendedor: ' + vVendedor;
            //Se agrega ventas exentas para factura de consumidor final
            IF NOT Transaction."Sale Is Return Sale" AND (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                DSTR1 := '      #L######################################                     #R########          ';
                Value[1] := 'Cajero: ' + Transaction."Staff ID" + '  Vendedor: ' + vVendedor;
                Value[2] := '$' + FORMAT(TotalVentE, 0, '<Integer Thousand><Decimals,3>');
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END
            ELSE
                IF NOT Transaction."Sale Is Return Sale" THEN BEGIN
                    IF (Item."No." = vProductoTelefonica1) OR (Item."No." = vProductoTelefonica2)
                    OR (Item."No." = vProductoTelefonica3) OR (Item."No." = vProductoTelefonica4) THEN
                        Value[2] := '$' + FORMAT(TotalVentG + TotalIVA + vCESC, 0, '<Integer Thousand><Decimals,3>')
                    ELSE
                        Value[2] := '$' + FORMAT(TotalVentG + TotalIVA + vCESC, 0, '<Integer Thousand><Decimals,3>');
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END
                ELSE
                    IF Transaction."Sale Is Return Sale" AND
               (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                        IF (Item."No." = vProductoTelefonica1) OR (Item."No." = vProductoTelefonica2)
                        OR (Item."No." = vProductoTelefonica3) OR (Item."No." = vProductoTelefonica4) THEN
                            Value[2] := '$' + FORMAT(TotalVentG + TotalIVA - vCESC, 0, '<Integer Thousand><Decimals,3>')
                        ELSE
                            Value[2] := '$' + FORMAT(TotalVentG + TotalIVA - vCESC, 0, '<Integer Thousand><Decimals,3>');
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END
                    ELSE BEGIN
                        Value[2] := '(' + '$' + FORMAT(TotalVentG + TotalIVA, 0, '<Integer Thousand><Decimals,3>') + ')';
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END
        END;

        CLEAR(TotalPercepcion);
        CLEAR(TotalRetencion);
        TotalPercepcion := ABS(Transaction."FSN Perception Amount");
        TotalRetencion := ABS(Transaction."FSN Retention Amount");
        IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Credito Fiscal") THEN BEGIN
        END
        ELSE
            IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                //iva retenido se movio a footer 6
            END
            ELSE
                IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                    TotalPercepcion := ABS(Transaction."FSN Perception Amount");
                    IF true then
                        DSTR1 := '                                                                             #R########'
                    ELSE
                        DSTR1 := '                                                    #L################     #R#######';
                    Value[1] := '$' + FORMAT(TotalPercepcion, 0, '<Integer Thousand><Decimals,3>');
                END;
        //Ventas Exentas
        IF NOT IsInvoice AND (Transaction."FSN Document Type" in [Transaction."FSN Document Type"::Ticket, Transaction."FSN Document Type"::"Devolucion Factura"]) AND NOT vIncomeExpense THEN BEGIN
            DSTR1 := '#L################## #R#################';
            Value[1] := TextTotVentasE;
            IF NOT Transaction."Sale Is Return Sale" THEN BEGIN
                Value[2] := '$' + FORMAT(TotalVentE, 0, '<Integer Thousand><Decimals,3>');
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END
            ELSE
                IF Transaction."Sale Is Return Sale" THEN BEGIN
                    Value[2] := '(' + '$' + FORMAT(TotalVentE, 0, '<Integer Thousand><Decimals,3>') + ')';
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
        END
        ELSE
            IF IsInvoice THEN BEGIN
                //ventas exentas, impresión se mueve junto a ventas gravadas
                //ventas exentas, impresión se agrega tambien despues de ventas no sujetas
                //ventas afectas agregadas para factura de consumidor final
                IF true then
                    DSTR1 := '      #L######################################                               #R########'
                ELSE
                    DSTR1 := '                                                    #L################     #R#######';

                //total el letras se quita
                //total letras se agrega
                //SODICO NOTEXTO Imprime en letras el total de la factura
                IF IsInvoice THEN BEGIN
                    PaymEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
                    IF PaymEntry.FIND('-') THEN
                        jContador := 1;
                    REPEAT
                        vAgregarSalesPersonNo := 0;
                        FOR iContador := 1 TO 30 DO BEGIN
                            TenderType.RESET;
                            TenderType.SETRANGE(Code, PaymEntry."Tender Type");
                            IF TenderType.FIND('-') THEN;
                            IF TenderType.Description = vMediosPago[iContador] THEN
                                vAgregarSalesPersonNo += 1;
                        END;
                        IF vAgregarSalesPersonNo = 0 THEN BEGIN
                            vMediosPago[jContador] := TenderType.Description;
                            jContador += 1;
                        END;
                    UNTIL PaymEntry.NEXT = 0;
                    Value[1] := 'Medios pago: ';
                    FOR iContador := 1 TO jContador DO BEGIN
                        Value[1] := Value[1] + vMediosPago[iContador] + ' ';
                    END;
                END;
                IF NOT Transaction."Sale Is Return Sale" AND (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                    Value[2] := '$' + FORMAT(TotalVentG, 0, '<Integer Thousand><Decimals,3>');
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END
                //iva percibido para credito fiscal y nota de credito
                ELSE BEGIN
                    Value[2] := '$' + FORMAT(TotalPercepcion, 0, '<Integer Thousand><Decimals,3>');
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
            END;
        //Ventas No Sujetas
        IF NOT IsInvoice AND (Transaction."FSN Document Type" IN [Transaction."FSN Document Type"::Ticket, Transaction."FSN Document Type"::"Devolucion Factura"]) AND NOT vIncomeExpense THEN BEGIN
            DSTR1 := '#L################## #R#################';
            Value[1] := TextVentNoSuj;
            IF NOT Transaction."Sale Is Return Sale" THEN BEGIN
                Value[2] := '$' + FORMAT(TotalNoSuj, 0, '<Integer Thousand><Decimals,3>');
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END
            ELSE
                IF Transaction."Sale Is Return Sale" THEN BEGIN
                    Value[2] := '(' + '$' + FORMAT(TotalNoSuj, 0, '<Integer Thousand><Decimals,3>') + ')';
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
        END
        //impresion ventas no sujetas agregada
        ELSE
            IF IsInvoice THEN BEGIN
                if true then
                    DSTR1 := '      #L######################################                               #R########'
                ELSE
                    DSTR1 := '                                                    #L################     #R#######';
                IF IsInvoice THEN BEGIN
                    FormatNoText1(Texto, ABS(Transaction.Payment));
                    TotalLetras := TotFac;
                    Value[1] := TotalLetras;
                END;

                IF NOT Transaction."Sale Is Return Sale" AND (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                    Value[2] := '$' + FORMAT(TotalVentG + TotalIVA, 0, '<Integer Thousand><Decimals,3>');
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END
                ELSE
                    IF NOT Transaction."Sale Is Return Sale" THEN BEGIN
                        Value[2] := '$' + FORMAT(TotalNoSuj, 0, '<Integer Thousand><Decimals,3>');
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END
                    ELSE
                        IF Transaction."Sale Is Return Sale" AND
                   (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                            Value[2] := '$' + FORMAT(TotalNoSuj, 0, '<Integer Thousand><Decimals,3>');
                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        END
                        ELSE BEGIN
                            Value[2] := '(' + '$' + FORMAT(TotalNoSuj, 0, '<Integer Thousand><Decimals,3>') + ')';
                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        END;

                //ventas exentas agregado
                if true then
                    DSTR1 := '      #L######################################                               #R########'
                ELSE
                    DSTR1 := '                                                    #L################     #R#######';
                Value[1] := vDecimalesTextoFactura + ' DOLARES';

                //iva retenido para facturas de consumidor final
                IF NOT Transaction."Sale Is Return Sale" AND (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                    Value[2] := '$' + FORMAT(TotalRetencion, 0, '<Integer Thousand><Decimals,3>');
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END
                ELSE
                    IF NOT Transaction."Sale Is Return Sale" THEN BEGIN
                        Value[2] := '$' + FORMAT(TotalVentE, 0, '<Integer Thousand><Decimals,3>');
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END
                    ELSE
                        IF Transaction."Sale Is Return Sale" AND
                     (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                            Value[2] := '$' + FORMAT(TotalVentE, 0, '<Integer Thousand><Decimals,3>');
                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        END
                        ELSE BEGIN
                            Value[2] := '(' + '$' + FORMAT(TotalVentE, 0, '<Integer Thousand><Decimals,3>') + ')';
                            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        END;
            END;
        //TOTAL
        IF NOT IsInvoice AND (Transaction."FSN Document Type" IN [Transaction."FSN Document Type"::Ticket, Transaction."FSN Document Type"::"Devolucion Factura"]) AND NOT vIncomeExpense THEN BEGIN
            DSTR1 := '#L##############           #R###########';
            Value[1] := TextTotal;
            IF NOT Transaction."Sale Is Return Sale" THEN BEGIN
                Value[2] := '$' + FORMAT(TotalVentG + TotalVentE + TotalNoSuj, 0, '<Integer Thousand><Decimals,3>');
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE)); //CSRG15102013 BOLD
            END
            ELSE
                IF Transaction."Sale Is Return Sale" THEN BEGIN
                    Value[2] := '$' + FORMAT(TotalVentG + TotalVentE + TotalNoSuj, 0, '<Integer Thousand><Decimals,3>');
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
        END
        //total movido a la derecha de la factura
        ELSE
            IF IsInvoice THEN BEGIN
                if true then
                    DSTR1 := '                                                                             #R########'
                ELSE
                    DSTR1 := '                                                    #L############         #R#######';
                IF NOT Transaction."Sale Is Return Sale" THEN BEGIN
                    IF (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                        Value[1] := '$' + FORMAT(TotalVentG + TotalIVA + TotalVentE + TotalNoSuj + TotalPercepcion
                        - TotalRetencion, 0, '<Integer Thousand><Decimals,3>');
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END
                    ELSE BEGIN
                        IF (Item."No." = vProductoTelefonica1) OR (Item."No." = vProductoTelefonica2)
                        OR (Item."No." = vProductoTelefonica3) OR (Item."No." = vProductoTelefonica4) THEN
                            Value[1] := '$' + FORMAT(TotalVentG + TotalIVA + TotalVentE + TotalNoSuj + TotalPercepcion
                            - TotalRetencion + vCESC, 0, '<Integer Thousand><Decimals,3>')
                        ELSE
                            Value[1] := '$' + FORMAT(TotalVentG + TotalIVA + TotalVentE + TotalNoSuj + TotalPercepcion
                            - TotalRetencion + vCESC, 0, '<Integer Thousand><Decimals,3>');
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END;
                END
                ELSE
                    IF Transaction."Sale Is Return Sale" AND
               (Transaction."FSN No. Serie NCF" = POSTerminal."FSN No. Serie Nota de Credito") THEN BEGIN
                        IF (Item."No." = vProductoTelefonica1) OR (Item."No." = vProductoTelefonica2)
                        OR (Item."No." = vProductoTelefonica3) OR (Item."No." = vProductoTelefonica4) THEN
                            Value[1] := '$' + FORMAT(TotalVentG + TotalIVA + TotalVentE + TotalNoSuj + TotalPercepcion
                            - TotalRetencion - vCESC, 0, '<Integer Thousand><Decimals,3>')
                        ELSE
                            Value[1] := '$' + FORMAT(TotalVentG + TotalIVA + TotalVentE + TotalNoSuj + TotalPercepcion
                            - TotalRetencion - vCESC, 0, '<Integer Thousand><Decimals,3>');
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END
                    ELSE BEGIN
                        Value[1] := '(' + '$' + FORMAT(TotalVentG + TotalIVA +
                        TotalVentE + TotalNoSuj + TotalPercepcion - TotalRetencion, 0, '<Integer Thousand><Decimals,3>') + ')';
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END;
            END;
        //total el letras se quita
        IncExpEntry.SETRANGE("Store No.", Transaction."Store No.");
        IncExpEntry.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
        IncExpEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
        IF IncExpEntry.FIND('-') THEN BEGIN
            REPEAT
                IncExpAcc.GET(IncExpEntry."Store No.", IncExpEntry."No.");
                DSTR1 := '#L#################### #N############';
                Value[1] := IncExpAcc.Description;
                Value[2] := POSFunctions.FormatAmount(-IncExpEntry.Amount);
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                IF IncExpAcc."Slip Text 1" <> '' THEN
                    PrintUL.PrintLine(Tray, IncExpAcc."Slip Text 1");
                IF IncExpAcc."Slip Text 2" <> '' THEN
                    PrintUL.PrintLine(Tray, IncExpAcc."Slip Text 2");
                TransInfoEntry.SETRANGE("Store No.", Transaction."Store No.");
                TransInfoEntry.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
                TransInfoEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
                TransInfoEntry.SETRANGE("Transaction Type", TransInfoEntry."Transaction Type"::"Income/Expense Entry");
                TransInfoEntry.SETRANGE("Line No.", IncExpEntry."Line No.");
                PrintUL.PrintTransInfoCode(TransInfoEntry, Tray, FALSE);
                if IncExpEntry."No." in ['18', '19', '20', '21'] then begin
                    if Parametrofsn.Get('PUNTOXPRESS', 'IMPRESIONMULT') and Parametrofsn.Activo then begin
                        TransIfoPX.Reset();
                        TransIfoPX.SetRange("Store No.", Transaction."Store No.");
                        TransIfoPX.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
                        TransIfoPX.SetRange("Transaction No.", Transaction."Transaction No.");
                        TransIfoPX.SetFilter(Information, Parametrofsn.SetFilterData1 + Parametrofsn.SetFilterData2);
                        if TransIfoPX.Find('-') then begin
                            TransPXInf.Reset();
                            TransInfoEntry.Reset();
                            TransPXInf.SETRANGE("Store No.", Transaction."Store No.");
                            TransPXInf.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
                            TransPXInf.SETRANGE("Transaction No.", Transaction."Transaction No.");
                            TransPXInf.SETRANGE(Infocode, 'TEXT');
                            IF TransPXInf.FIND('-') THEN BEGIN
                                repeat
                                    if (StrPos(TransPXInf.Information, 'Autorizacion') > 0) or (StrPos(TransPXInf.Information, 'Ordenante') > 0) or
                                    (StrPos(TransPXInf.Information, 'Beneficiario') > 0) or (StrPos(TransPXInf.Information, 'Num. de documento') > 0) or
                                    (StrPos(TransPXInf.Information, 'País de origen') > 0) or (StrPos(TransPXInf.Information, 'País destino') > 0) OR
                                    (StrPos(TransPXInf.Information, 'PIN') > 0) then begin
                                        Value[2] := '';
                                        ComentarioPX := TransPXInf.Information;
                                        CurrentLine := '';
                                        PInicial := 1;

                                        while PInicial <= STRLEN(ComentarioPX) do begin
                                            Cespacio := STRPOS(COPYSTR(ComentarioPX, PInicial), ' ');
                                            if Cespacio = 0 then
                                                Cespacio := STRLEN(ComentarioPX) - PInicial + 2;

                                            NComentario := COPYSTR(ComentarioPX, PInicial, Cespacio - 1);
                                            PInicial := PInicial + Cespacio;

                                            if STRLEN(CurrentLine) + STRLEN(NComentario) + 1 > 40 then begin
                                                Value[1] := CurrentLine;
                                                PrintUL.PrintLine(Tray, Value[1]);
                                                CurrentLine := NComentario;
                                            end else begin
                                                if CurrentLine <> '' then
                                                    CurrentLine := CurrentLine + ' ' + NComentario
                                                else
                                                    CurrentLine := NComentario;
                                            end;
                                        end;
                                        if CurrentLine <> '' then begin
                                            Value[1] := CurrentLine;
                                            PrintUL.PrintLine(Tray, Value[1]);
                                        end;
                                    end
                                until TransPXInf.Next() = 0
                            END;
                        end;
                    end;



                    TransInfoEntry.Reset();
                    TransInfoEntry.SETRANGE("Store No.", Transaction."Store No.");
                    TransInfoEntry.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
                    TransInfoEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
                    TransInfoEntry.SETRANGE("Transaction Type", TransInfoEntry."Transaction Type"::Header);
                    TransInfoEntry.SETRANGE(Infocode, 'PUNTOEXPRESS');
                    if TransInfoEntry.Find('-') then
                        repeat
                            Value[2] := '';
                            ComentarioPX := TransInfoEntry.Information;
                            CurrentLine := '';
                            PInicial := 1;

                            while PInicial <= STRLEN(ComentarioPX) do begin
                                Cespacio := STRPOS(COPYSTR(ComentarioPX, PInicial), ' ');
                                if Cespacio = 0 then
                                    Cespacio := STRLEN(ComentarioPX) - PInicial + 2;

                                NComentario := COPYSTR(ComentarioPX, PInicial, Cespacio - 1);
                                PInicial := PInicial + Cespacio;

                                if STRLEN(CurrentLine) + STRLEN(NComentario) + 1 > 40 then begin
                                    Value[1] := CurrentLine;
                                    PrintUL.PrintLine(Tray, Value[1]);
                                    CurrentLine := NComentario;
                                end else begin
                                    if CurrentLine <> '' then
                                        CurrentLine := CurrentLine + ' ' + NComentario
                                    else
                                        CurrentLine := NComentario;
                                end;
                            end;
                            if CurrentLine <> '' then begin
                                Value[1] := CurrentLine;
                                PrintUL.PrintLine(Tray, Value[1]);
                            end;
                        until TransInfoEntry.Next() = 0;
                end;
            UNTIL IncExpEntry.NEXT = 0;
            PrintUL.PrintSeperator(Tray);
        END;

        IF NOT IsInvoice THEN BEGIN
            //Imprimir nombre Cajero...
            rStaff1.RESET;
            rStaff1.SETRANGE(ID, SalesEntry."Staff ID");
            IF rStaff1.FINDFIRST() THEN BEGIN
                DSTR1 := '  #L####################################';
                Value[1] := 'Cajero:' + ' ' + rStaff1."Name on Receipt";
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END;
            //Imprimir nombre de vendedor(es)
            lSalesPersonTmp.RESET;//28981
            lSalesPersonTmp.DELETEALL;
            SalesEntryStaff.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
            SalesEntryStaff.SetRange(SalesEntryStaff."Store No.", Transaction."Store No.");
            SalesEntryStaff.SetRange(SalesEntryStaff."POS Terminal No.", Transaction."POS Terminal No.");
            SalesEntryStaff.SetRange(SalesEntryStaff."Transaction No.", Transaction."Transaction No.");
            IF SalesEntryStaff.FIND('-') THEN
                REPEAT
                    IF NOT lSalesPersonTmp.GET(SalesEntryStaff."Sales Staff") THEN BEGIN
                        lSalesPersonTmp.INIT();
                        lSalesPersonTmp.ID := SalesEntryStaff."Sales Staff";
                        lSalesPersonTmp.INSERT;
                    END;
                UNTIL SalesEntryStaff.NEXT = 0;

            lSalesPersonTmp.RESET;
            IF lSalesPersonTmp.FIND('-') THEN
                REPEAT
                    vendedor += lSalesPersonTmp.ID + ' ';
                UNTIL lSalesPersonTmp.NEXT = 0;

            DSTR1 := '  #L####################################';
            Value[1] := 'Vendedor:' + vendedor;
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            //Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            Value[1] := '';
            PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;
        IF NOT IsInvoice THEN BEGIN
            //Imprime los medios de pago con se cancelo la transaccion
            IF NOT Transaction."Post as Shipment" THEN BEGIN
                PrintUL.PrintSeperator(Tray);
                PrintUL.PrintPaymInfo(Transaction, Tray);
            END;

            POSTerminal.GET(Transaction."POS Terminal No.");
            IF POSTerminal."Print Number of Items" AND (totalNumberOfItems <> 0) THEN BEGIN
                CLEAR(Value);
                PrintUL.PrintSeperator(Tray);
                DSTR1 := '#L###################### #R#############';

                Value[1] := Text151;
                Value[2] := POSFunctions.FormatQty(totalNumberOfItems);
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                PrintUL.PrintSeperator(Tray);
            END;
        END;
        PrintUL.PrintLoyalty(Transaction, 2);//DETALLE DE PUNTOS VIP

        DSTR1 := COPYSTR('                     ', 1);
        Value[1] := '';
        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //no imprimir ahorro cuando es devolución
        IF POSTerminal."Print Total Savings" AND (totalSavings <> 0) AND NOT Transaction."Sale Is Return Sale" THEN BEGIN
            //Descuento
            IF NOT IsInvoice THEN BEGIN
                DSTR1 := ' #C#################';
                IF Transaction."Customer Disc. Group" = 'VIP' THEN
                    Value[1] := TextDescuentoVip + ':'
                ELSE
                    Value[1] := TextDescuento;

                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), TRUE, TRUE, TRUE, FALSE));

                //Imprimir Linea en blanco...
                DSTR1 := COPYSTR('                     ', 1);
                Value[1] := '';
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                IF NOT Transaction."Sale Is Return Sale" THEN BEGIN

                    DSTR1 := '  #L###################';
                    Value[1] := '$' + FORMAT(-1 * Descuento, 0, '<Integer Thousand><Decimals,3>');
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), TRUE, TRUE, TRUE, FALSE));
                END
                ELSE
                    IF Transaction."Sale Is Return Sale" THEN BEGIN
                        Value[1] := '(' + '$' + FORMAT(Descuento, 0, '<Integer Thousand><Decimals,3>') + ')';
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END;
            END;
        END;

        if Parametrofsn.Get('PUNTOXPRESS', 'IMPRESIONEXTRA') and Parametrofsn.Activo then begin
            ComentarioPX := Parametrofsn.Valor;
            DSTR1 := '#L######################################';
            TransIfoPX.Reset();
            TransIfoPX.SetRange("Store No.", Transaction."Store No.");
            TransIfoPX.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
            TransIfoPX.SetRange("Transaction No.", Transaction."Transaction No.");
            TransIfoPX.SetFilter(Information, Parametrofsn.SetFilterData1 + Parametrofsn.SetFilterData2);
            if TransIfoPX.Find('-') then begin
                CurrentLine := '';
                PInicial := 1;

                while PInicial <= STRLEN(ComentarioPX) do begin
                    Cespacio := STRPOS(COPYSTR(ComentarioPX, PInicial), ' ');
                    if Cespacio = 0 then
                        Cespacio := STRLEN(ComentarioPX) - PInicial + 2;

                    NComentario := COPYSTR(ComentarioPX, PInicial, Cespacio - 1);
                    PInicial := PInicial + Cespacio;

                    if STRLEN(CurrentLine) + STRLEN(NComentario) + 1 > 40 then begin
                        Value[1] := CurrentLine;
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        CurrentLine := NComentario;
                    end else begin
                        if CurrentLine <> '' then
                            CurrentLine := CurrentLine + ' ' + NComentario
                        else
                            CurrentLine := NComentario;
                    end;
                end;
                if CurrentLine <> '' then begin
                    Value[1] := CurrentLine;
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                end;
            end;
        end;

        Parametrofsn.reset();
        if Parametrofsn.Get('PUNTOXPRESS', 'IMPRESIONMULT') and Parametrofsn.Activo then begin
            ComentarioPX := Parametrofsn.Valor;
            DSTR1 := '#L######################################';
            TransIfoPX.Reset();
            TransIfoPX.SetRange("Store No.", Transaction."Store No.");
            TransIfoPX.SetRange("POS Terminal No.", Transaction."POS Terminal No.");
            TransIfoPX.SetRange("Transaction No.", Transaction."Transaction No.");
            TransIfoPX.SetFilter(Information, Parametrofsn.SetFilterData1 + Parametrofsn.SetFilterData2);
            if TransIfoPX.Find('-') then begin
                CurrentLine := '';
                PInicial := 1;



                // Espacio para firma del cliente
                DSTR1 := '#C######################################';
                Value[1] := '';
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                Value[1] := '_________________________';
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), false, true, FALSE, FALSE));

                Value[1] := 'Firma Cliente';
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), false, true, FALSE, FALSE));
                // Espacio para firma del cliente
                DSTR1 := '#L######################################';
                Value[1] := '';
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                while PInicial <= STRLEN(ComentarioPX) do begin
                    Cespacio := STRPOS(COPYSTR(ComentarioPX, PInicial), ' ');
                    if Cespacio = 0 then
                        Cespacio := STRLEN(ComentarioPX) - PInicial + 2;

                    NComentario := COPYSTR(ComentarioPX, PInicial, Cespacio - 1);
                    PInicial := PInicial + Cespacio;

                    if STRLEN(CurrentLine) + STRLEN(NComentario) + 1 > 40 then begin
                        Value[1] := CurrentLine;
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        CurrentLine := NComentario;
                    end else begin
                        if CurrentLine <> '' then
                            CurrentLine := CurrentLine + ' ' + NComentario
                        else
                            CurrentLine := NComentario;
                    end;
                end;
                if CurrentLine <> '' then begin
                    Value[1] := CurrentLine;
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                end;
            end;
        end;
    end;


    /////////////////////////////////////////FIN DETALLE//////////////////////////////////////

    procedure InsertIntoRecipeBuffer(TransSalesEntry: Record "LSC Trans. Sales Entry"; var RecipeBufferTEMP: Record "LSC Trans. Sales Entry" temporary; ParentItemLine: Record "LSC Trans. Sales Entry"; var RecipeBufferDetailTEMP_p: Record "LSC Trans. Discount Entry" temporary)
    var
        EntryNoOfMasterLine: Integer;
        ItemInfocodeItemModifier: Record "LSC Infocode";
        TransDiscEntry_l: Record "LSC Trans. Discount Entry";
    begin
        //InsertIntoRecipeBuffer
        IF TransSalesEntry."Parent Line No." = 0 THEN BEGIN
            RecipeBufferTEMP.RESET;
            RecipeBufferTEMP.SETCURRENTKEY("Item No.", "Variant Code");
            RecipeBufferTEMP.SETRANGE("Item No.", TransSalesEntry."Item No.");
            RecipeBufferTEMP.SETFILTER("Variant Code", '%1', TransSalesEntry."Variant Code");
            RecipeBufferTEMP.SETFILTER("Orig. from Infocode", '%1', TransSalesEntry."Orig. from Infocode");
            IF RecipeBufferTEMP.FINDFIRST THEN BEGIN
                RecipeBufferTEMP.Quantity := RecipeBufferTEMP.Quantity + TransSalesEntry.Quantity;
                RecipeBufferTEMP."Net Amount" := RecipeBufferTEMP."Net Amount" + TransSalesEntry."Net Amount";
                RecipeBufferTEMP."VAT Amount" := RecipeBufferTEMP."VAT Amount" + TransSalesEntry."VAT Amount";
                RecipeBufferTEMP."Discount Amount" := RecipeBufferTEMP."Discount Amount" + TransSalesEntry."Discount Amount";
                RecipeBufferTEMP.MODIFY;

                IF GenPosFunc."Print Disc/Cpn Info on Slip" IN
                  [GenPosFunc."Print Disc/Cpn Info on Slip"::"Detail for each line and Sub-total",
                  GenPosFunc."Print Disc/Cpn Info on Slip"::"Detail information for each line"] THEN
                    PrintUL.BufferLineDiscountDetails(TransSalesEntry, RecipeBufferTEMP, RecipeBufferDetailTEMP_p);
            END ELSE BEGIN
                CLEAR(RecipeBufferTEMP);
                RecipeBufferTEMP := TransSalesEntry;
                RecipeBufferTEMP.INSERT;
                IF GenPosFunc."Print Disc/Cpn Info on Slip" IN
                  [GenPosFunc."Print Disc/Cpn Info on Slip"::"Detail for each line and Sub-total",
                  GenPosFunc."Print Disc/Cpn Info on Slip"::"Detail information for each line"] THEN BEGIN
                    CLEAR(RecipeBufferDetailTEMP_p);
                    PrintUL.BufferLineDiscountDetails(TransSalesEntry, RecipeBufferTEMP, RecipeBufferDetailTEMP_p);
                END;
            END;
        END
        ELSE BEGIN
            CLEAR(ItemInfocodeItemModifier);
            IF TransSalesEntry."Orig. from Infocode" <> '' THEN
                IF ItemInfocodeItemModifier.GET(TransSalesEntry."Orig. from Infocode") THEN;
            IF (ItemInfocodeItemModifier."Print Item Modifier on Receipt" =
                 ItemInfocodeItemModifier."Print Item Modifier on Receipt"::"Print All") OR
               ((ItemInfocodeItemModifier."Print Item Modifier on Receipt" =
                 ItemInfocodeItemModifier."Print Item Modifier on Receipt"::"Skip Zero Price") AND
                (TransSalesEntry."Net Amount" + TransSalesEntry."VAT Amount" <> 0)) THEN BEGIN
                EntryNoOfMasterLine := 0;
                RecipeBufferTEMP.RESET;
                RecipeBufferTEMP.SETCURRENTKEY("Item No.", "Variant Code");
                RecipeBufferTEMP.SETRANGE("Item No.", ParentItemLine."Item No.");
                RecipeBufferTEMP.SETFILTER("Variant Code", '%1', ParentItemLine."Variant Code");
                RecipeBufferTEMP.SETFILTER("Orig. from Infocode", '%1', ParentItemLine."Orig. from Infocode");
                IF RecipeBufferTEMP.FINDFIRST THEN BEGIN
                    EntryNoOfMasterLine := RecipeBufferTEMP."Line No.";
                    RecipeBufferTEMP.SETRANGE("Parent Line No.", EntryNoOfMasterLine);
                    RecipeBufferTEMP.SETRANGE("Item No.", TransSalesEntry."Item No.");
                    RecipeBufferTEMP.SETFILTER("Variant Code", '%1', TransSalesEntry."Variant Code");
                    RecipeBufferTEMP.SETRANGE("Orig. from Infocode");
                    IF RecipeBufferTEMP.FINDFIRST THEN BEGIN
                        RecipeBufferTEMP.Quantity := RecipeBufferTEMP.Quantity + TransSalesEntry.Quantity;
                        RecipeBufferTEMP."Net Amount" := RecipeBufferTEMP."Net Amount" + TransSalesEntry."Net Amount";
                        RecipeBufferTEMP."VAT Amount" := RecipeBufferTEMP."VAT Amount" + TransSalesEntry."VAT Amount";
                        RecipeBufferTEMP."Discount Amount" := RecipeBufferTEMP."Discount Amount" + TransSalesEntry."Discount Amount";
                        RecipeBufferTEMP.MODIFY;
                    END
                    ELSE BEGIN
                        RecipeBufferTEMP := TransSalesEntry;
                        RecipeBufferTEMP."Parent Line No." := EntryNoOfMasterLine;
                        RecipeBufferTEMP.INSERT;
                    END;
                END
                ELSE BEGIN
                    RecipeBufferTEMP := TransSalesEntry;
                    RecipeBufferTEMP."Parent Line No." := EntryNoOfMasterLine;
                    RecipeBufferTEMP.INSERT;
                END;
            END;
        END;
    end;

    procedure PrintLineRemision(Tray: Integer; PrintSep: Boolean; Information: Text[100]; Amount: Decimal)
    var
        DSTR: Text[100];
        InfoText: Text[100];
    begin
        //FASANI Creditos Padre Hijo
        // Impresion de InfoCode TXTFACT para notas de remision
        DSTR := '            #L####################################  #R####                     #R######';
        // Imprimir la linea de remision
        Value[1] := COPYSTR(Information, 1, 38);
        Value[2] := POSFunctions.FormatAmount(-Amount);
        Value[3] := POSFunctions.FormatAmount(-Amount) + 'G';
        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR), FALSE, FALSE, FALSE, FALSE));
        PrintUL.AddPrintLine(350, 2, NodeName, Value, DSTR, FALSE, FALSE, FALSE, FALSE, Tray);
        IF PrintSep THEN
            PrintUL.PrintLine(Tray, '');
    end;

    procedure PrintSPOSalesInfo(var Transaction: Record "LSC Transaction Header"; Tray: Integer): Integer
    var
        PaymEntry: Record "LSC Trans. Payment Entry";
        Tendertype: Record "LSC Tender Type";
        DSTR1: Text[100];
        LineCount: Integer;
    begin
        //PrintSPOSalesInfo
        LineCount := 0;
        totSPOAmount := 0;
        CLEAR(PaymEntry);
        PaymEntry.SETRANGE("Store No.", Transaction."Store No.");
        PaymEntry.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
        PaymEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
        IF PaymEntry.FIND('-') THEN BEGIN
            REPEAT
                IF Tendertype.GET(PaymEntry."Store No.", PaymEntry."Tender Type") THEN
                    IF Tendertype."Auto Account Payment Tender" THEN
                        totSPOAmount := totSPOAmount - PaymEntry."Amount Tendered";
            UNTIL PaymEntry.NEXT = 0;
            DSTR1 := '#L####################### #R#########';
            CLEAR(Value);
            Value[1] := Text216 + ' ';
            NodeName[1] := 'Total Text';
            Value[2] := POSFunctions.FormatAmount(totSPOAmount);
            NodeName[2] := 'Total Amount';
            IF (totSPOAmount <> 0) THEN BEGIN
                LineCount := LineCount + 1;
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
                PrintUL.AddPrintLine(600, 2, NodeName, Value, DSTR1, FALSE, FALSE, FALSE, FALSE, Tray);
            END;
        END;
        EXIT(LineCount);
    end;

    procedure FormatNoText1(NoText: array[2] of Text[75]; No: Decimal)
    var
        ImpriExponent: Boolean;
        Udades: Integer;
        Decenas: Integer;
        Centenas: Integer;
        Exponente: Integer;
        NoTextInd: Integer;
        PosicionDecimal: Integer;
        Decimales: Text[30];
    begin

        CLEAR(NoText);
        CLEAR(TextImporteCheque);
        TextImporteCheque := FORMAT(No);
        NoTextInd := 1;

        IF No > 999999999 THEN
            ERROR('%1 es demasiado grande para convertir a texto', No);

        IF ROUND(No, 1, '<') = 0 THEN
            AddToNoText(NoText, NoTextInd, 'CERO');

        CentenaMillom := ROUND(No, 1, '<') DIV 100000000;
        Recordar := ROUND(No, 1, '<') MOD 100000000;
        DecenaMilon := Recordar DIV 10000000;
        Recordar := Recordar MOD 10000000;
        UdadMillon := Recordar DIV 1000000;
        Recordar := Recordar MOD 1000000;
        CentenaMiles := Recordar DIV 100000;
        Recordar := Recordar MOD 100000;
        DecenaMiles := Recordar DIV 10000;
        Recordar := Recordar MOD 10000;
        UdadsMiles := Recordar DIV 1000;
        Recordar := Recordar MOD 1000;
        Centenas := Recordar DIV 100;
        Recordar := Recordar MOD 100;
        Decenas := Recordar DIV 10;
        Cantidades := Recordar MOD 10;
        NroDecimales := STRLEN(FORMAT(No, 1, '<decimals>'));
        //IF NroDecimales >0 THEN
        //  NroDecimales := NroDecimales - 1;

        AddToNoText(NoText, NoTextInd, TextoCentenasMillon(CentenaMillom, DecenaMilon, UdadMillon, TRUE));
        AddToNoText(NoText, NoTextInd, TextoDecenasMillon(CentenaMillom, DecenaMilon, UdadMillon, TRUE));
        AddToNoText(NoText, NoTextInd, TextoCientosMIles(CentenaMiles, DecenaMiles, UdadsMiles, FALSE));
        AddToNoText(NoText, NoTextInd, TextoDecenasMiles(CentenaMiles, DecenaMiles, UdadsMiles, FALSE));
        AddToNoText(NoText, NoTextInd, TextoCentenas(Centenas, Decenas, Cantidades, FALSE));
        AddToNoText(NoText, NoTextInd, TextDecenasUdads(Decenas, Cantidades, FALSE));

        Longitud := STRLEN(TextImporteCheque);
        PosicionDecimal := STRPOS(TextImporteCheque, '.');
        IF PosicionDecimal = 0 THEN
            Decimales := '00' ELSE
            Decimales := COPYSTR(TextImporteCheque, PosicionDecimal + 1, Longitud - PosicionDecimal);
        IF STRLEN(Decimales) = 1 THEN
            Decimales := Decimales + '0';
        AddToNoText(NoText, NoTextInd, '');
        vDecimalesTextoFactura := 'CON ' + Decimales + '/100';
    end;

    procedure TextoDecenasMiles(Centenas: Integer; Decena: Integer; Cantidades: Integer; Masc: Boolean): Text[250]
    begin

        IF (Centenas <> 0) AND (Decena = 0) AND (Cantidades = 0) THEN
            EXIT('MIL ');
        IF (Centenas = 0) AND (Decena = 0) AND (Cantidades = 1) THEN
            EXIT('MIL ');
        IF (Decena <> 0) OR (Cantidades <> 0) THEN
            EXIT(TextDecenasUdads(Decena, Cantidades, Masc) + 'MIL ');
    end;

    procedure TextoCientosMIles(Centenas: Integer; Decena: Integer; Cantidades: Integer; Masc: Boolean): Text[250]
    begin

        IF Centenas <> 0 THEN
            EXIT(TextoCentenas(Centenas, Decena, Cantidades, Masc))
    end;

    procedure TextoDecenasMillon(Centenas: Integer; Decena: Integer; Cantidades: Integer; Masc: Boolean): Text[250]
    begin

        IF (Centenas <> 0) AND (Decena = 0) AND (Cantidades = 0) THEN
            EXIT('MILLONES ');
        IF (Centenas = 0) AND (Decena = 0) AND (Cantidades = 1) THEN
            EXIT('UN MILLON ');
        IF (Decena <> 0) OR (Cantidades <> 0) THEN
            EXIT(TextDecenasUdads(Decena, Cantidades, Masc) + 'MILLONES ');
    end;

    procedure TextDecenasUdads(Decenas: Integer; Cantidades: Integer; Masc: Boolean): Text[250]
    begin

        CASE Decenas OF
            0:
                EXIT(TextoUdads(Cantidades, Masc));
            1:
                CASE Cantidades OF
                    0:
                        EXIT('DIEZ ');
                    1:
                        EXIT('ONCE ');
                    2:
                        EXIT('DOCE ');
                    3:
                        EXIT('TRECE ');
                    4:
                        EXIT('CATORCE ');
                    5:
                        EXIT('QUINCE ');
                    ELSE
                        EXIT('DIECI' + TextoUdads(Cantidades, Masc));
                END;
            2:
                IF Cantidades = 0 THEN
                    EXIT('VEINTE ')
                ELSE
                    EXIT('VEINTI' + TextoUdads(Cantidades, Masc));
            3:
                IF Cantidades = 0 THEN
                    EXIT('TREINTA ')
                ELSE
                    EXIT('TREINTA Y ' + TextoUdads(Cantidades, Masc));
            4:
                IF Cantidades = 0 THEN
                    EXIT('CUARENTA ')
                ELSE
                    EXIT('CUARENTA Y ' + TextoUdads(Cantidades, Masc));
            5:
                IF Cantidades = 0 THEN
                    EXIT('CINCUENTA ')
                ELSE
                    EXIT('CINCUENTA Y ' + TextoUdads(Cantidades, Masc));
            6:
                IF Cantidades = 0 THEN
                    EXIT('SESENTA ')
                ELSE
                    EXIT('SESENTA Y ' + TextoUdads(Cantidades, Masc));
            7:
                IF Cantidades = 0 THEN
                    EXIT('SETENTA ')
                ELSE
                    EXIT('SETENTA Y ' + TextoUdads(Cantidades, Masc));
            8:
                IF Cantidades = 0 THEN
                    EXIT('OCHENTA ')
                ELSE
                    EXIT('OCHENTA Y ' + TextoUdads(Cantidades, Masc));
            9:
                IF Cantidades = 0 THEN
                    EXIT('NOVENTA ')
                ELSE
                    EXIT('NOVENTA Y ' + TextoUdads(Cantidades, Masc));
        END;
    end;

    procedure TextoUdads(Cantidades: Integer; Masc: Boolean): Text[250]
    begin

        CASE Cantidades OF
            0:
                EXIT('');
            1:
                IF Masc THEN
                    EXIT('UN ')
                ELSE
                    EXIT('UNO ');
            2:
                EXIT('DOS ');
            3:
                EXIT('TRES ');
            4:
                EXIT('CUATRO ');
            5:
                EXIT('CINCO ');
            6:
                EXIT('SEIS ');
            7:
                EXIT('SIETE ');
            8:
                EXIT('OCHO ');
            9:
                EXIT('NUEVE ');
        END;
    end;

    procedure TextoCentenasMillon(Centenas: Integer; Decena: Integer; Cantidades: Integer; Masc: Boolean): Text[250]
    begin

        IF Centenas <> 0 THEN
            EXIT(TextoCentenas(Centenas, Decena, Cantidades, TRUE));
    end;

    procedure TextoCentenas(Centenas: Integer; Decena: Integer; Cantidades: Integer; Masc: Boolean): Text[250]
    begin

        IF Centenas = 0 THEN
            EXIT('');
        IF Masc THEN
            CASE Centenas OF
                1:
                    IF (Decenas = 0) AND (Cantidades = 0) THEN
                        EXIT('CIEN ')
                    ELSE
                        EXIT('CIENTO ');
                2:
                    EXIT('DOSCIENTOS ');
                3:
                    EXIT('TRESCIENTOS ');
                4:
                    EXIT('CUATROCIENTOS ');
                5:
                    EXIT('QUINIENTOS ');
                6:
                    EXIT('SEISCIENTOS ');
                7:
                    EXIT('SETECIENTOS ');
                8:
                    EXIT('OCHOCIENTOS ');
                9:
                    EXIT('NOVECIENTOS ');
            END
        ELSE
            CASE Centenas OF
                1:
                    IF (Decenas = 0) AND (Cantidades = 0) THEN
                        EXIT('CIEN ')
                    ELSE
                        EXIT('CIENTO ');
                2:
                    EXIT('DOSCIENTOS ');
                3:
                    EXIT('TRESCIENTOS ');
                4:
                    EXIT('CUATROCIENTOS ');
                5:
                    EXIT('QUINIENTOS ');
                6:
                    EXIT('SEISCIENTOS ');
                7:
                    EXIT('SETECIENTOS ');
                8:
                    EXIT('OCHOCIENTOS ');
                9:
                    EXIT('NOVECIENTOS ');
            END;
    end;

    procedure AddToNoText(NoText: array[2] of Text[75]; NoTextInd: Integer; SumaTexto: Text[30])
    begin

        WHILE STRLEN(NoText[NoTextInd] + SumaTexto) > MAXSTRLEN(NoText[1]) DO BEGIN
            NoTextInd := NoTextInd + 1;
            IF NoTextInd > ARRAYLEN(NoText) THEN
                ERROR('%1 \ es un número demasiado largo.', SumaTexto);
        END;

        TotFac := DELCHR(TotFac + SumaTexto, '<');
        NoText[NoTextInd] := DELCHR(NoText[NoTextInd] + SumaTexto, '<');
    end;

    procedure DiaATexto(num: Integer): Text[50]
    begin

        CASE num OF
            1:
                EXIT('uno');
            2:
                EXIT('dos');
            3:
                EXIT('tres');
            4:
                EXIT('cuatro');
            5:
                EXIT('cinco');
            6:
                EXIT('seis');
            7:
                EXIT('siete');
            8:
                EXIT('ocho');
            9:
                EXIT('nueve');
            10:
                EXIT('diez');
            11:
                EXIT('once');
            12:
                EXIT('doce');
            13:
                EXIT('trece');
            14:
                EXIT('catorce');
            15:
                EXIT('quince');
            16:
                EXIT('dieciseis');
            17:
                EXIT('diecisiete');
            18:
                EXIT('dieciocho');
            19:
                EXIT('diecinueve');
            20:
                EXIT('veinte');
            21:
                EXIT('veintiuno');
            22:
                EXIT('veintidos');
            23:
                EXIT('veintitres');
            24:
                EXIT('veinticuatro');
            25:
                EXIT('veinticinco');
            26:
                EXIT('veintiseis');
            27:
                EXIT('veintisiete');
            28:
                EXIT('veintiocho');
            29:
                EXIT('veintinueve');
            30:
                EXIT('treinta');
            31:
                EXIT('treinta y uno');
        END;
    end;

    //////////////////////////////////////////ZZZZZZZZZ//////////////////////////////////////////////////////
    procedure PrintXZReportSV_Z(): Boolean
    var
        Text177: Label 'Are you sure you want to print a Z Report?';
        SuspendTrans: Integer;
        POSTransCU: CodeUnit "LSC POS Transaction";
        DiscoutAmount: Decimal;
        AmountTotal: Decimal;
        PaymentFilt: Record "LSC Trans. Payment Entry";
    begin
        IF NOT PosConfirm(Text177, true) THEN
            EXIT;

        //? El metodo navito se puede aplicar sin problema para anular las transacciones
        POSTransCU.ZReportSuspendProcess(SuspendTrans);

        //longitud campos texto autorizacion 20a30
        IF NOT Staff.GET(Globals.StaffID) THEN
            EXIT(TRUE);
        IF NOT Terminal.GET(Globals.TerminalNo) THEN
            EXIT(TRUE);
        IF NOT PrintUL.OpenReceiptPrinter(2, 'TENDER', 'ZXREPORT', 0, '') THEN
            EXIT(FALSE);
        Store.GET(Globals.StoreNo());

        IF FiscalON THEN BEGIN
            PrintUL.FiscalPrintXZReport(RunParameter::Z);
            IF OnlyFiscal THEN
                EXIT(PrintUL.ClosePrinter(2));
        END;

        IF NOT Terminal."Terminal Statement" THEN
            Terminal."Statement Method" := Store."Statement Method";

        SCode := POSFunctions.GetStatementCode;

        Transaction.Date := TODAY;
        Transaction.Time := TIME;
        PrintUL.PrintSeperator(2);

        //X or Z Report..
        DSTR1 := '#C############################';
        Value[1] := Text106;
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
        IF GenPosFunc."TS Floating Cashier" AND
           (Terminal."Statement Method" = Terminal."Statement Method"::Staff) AND
           (Globals.GetValue('TS_ERROR') <> '') THEN BEGIN
        END;
        PrintUL.PrintSeperator(2);
        //información general

        DSTR1 := '#L######################################';
        Value[1] := 'Fecha: ' + FORMAT(TODAY, 0, '<Day,2>/<Month,2>/<Year4>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        DSTR1 := '#L######################################';
        Value[1] := 'Hora: ' + FORMAT(TIME(), 0, '<Hours12>:<Minutes,2> <AM/PM>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Nombre de la empresa...
        rCompanyInfo.GET();
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := rCompanyInfo.Name;
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Codigo Tipo Contribuyente y  No. Reg. Contribuyente de la empresa...
        rCompanyInfo.GET();
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := TextNRC + ':' + rCompanyInfo."FSN NRC";
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir NIT de la empresa...
        rCompanyInfo.GET();
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := TextRNC + ':' + rCompanyInfo."Federal ID No.";
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Giro de la empresa...
        rCompanyInfo.GET();
        DSTR1 := COPYSTR('#C#######################################', 1);
        Value[1] := TextGIRO + '::' + COPYSTR(rCompanyInfo."FSN NRC Description", 1, 26);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        DSTR1 := COPYSTR('#C#######################################', 1);
        Value[1] := COPYSTR(rCompanyInfo."FSN NRC Description", 26, 39);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Nombre de la tienda.
        DSTR1 := COPYSTR('#L######################################', 1);
        Value[1] := Store.Name;
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir 1era. direccion de la tienda.
        DSTR1 := COPYSTR('#L######################################', 1);
        Value[1] := Store.Address;
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir 2da. direccion de la tienda.
        IF Store."Address 2" <> '' THEN BEGIN
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := Store."Address 2";
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;

        //Imprimir el No. de la Caja..
        DSTR1 := COPYSTR('#L################## #R#################', 1);
        Value[1] := TextCodTienda + ' ' + Store."No.";
        Value[2] := TextCaja + ' ' + Terminal."No.";
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        PrintUL.PrintSeperator(2);
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := 'Corte Z No.: ' + INCSTR(Terminal."Last Z-Report");
        ZReportID := INCSTR(Terminal."Last Z-Report");
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
        PrintUL.PrintSeperator(2);

        NicopuPaymentEntry.RESET;
        NicopuPaymentEntry.SetRange(NicopuPaymentEntry."POS Terminal No.", POSSESSION.TerminalNo());
        NicopuPaymentEntry.SetRange(NicopuPaymentEntry."Z-Report ID", '');
        NicopuPaymentEntry.SetRange(NicopuPaymentEntry."Tender Type", '11');
        NicopuPaymentEntry.SetRange(NicopuPaymentEntry."Safe type", NicopuPaymentEntry."Safe type"::" ");
        if NicopuPaymentEntry.Find('-') then begin
            repeat
                NicopuSUM := NicopuSUM + NicopuPaymentEntry."Amount Tendered";
                Nicopu := Nicopu + NicopuPaymentEntry."Amount in Currency";
            until NicopuPaymentEntry.Next() = 0;
        end;

        PrintUL.PrintSeperator(2);
        DSTR1 := '#C######################################';
        Value[1] := 'NICOPUNTOS: ' + Format(Nicopu) + '  ' + Format(NicopuSUM);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
        //PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), true, false, true, false));
        PrintUL.PrintSeperator(2);

        //  Totals for LCY
        IF LocalTotal <> 0 THEN BEGIN
            PrintUL.PrintSeperator(2);
            DSTR1 := '#L########              #R##############';
            Value[1] := Text005 + ':';
            Value[2] := POSFunctions.FormatAmount(LocalTotal);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
        END;

        //  Totals for FCY
        PrintUL.PrintLine(2, '');
        TenderType.SETRANGE("Foreign Currency", TRUE);

        TotalLCYInCurrency := 0;
        //PrintXZLines();
        IF TotalLCYInCurrency <> 0 THEN BEGIN
            PrintUL.PrintSeperator(2);
            DSTR1 := '#L##################### #R##############';
            Value[1] := Text300;
            Value[2] := POSFunctions.FormatAmount(TotalLCYInCurrency);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
            PrintUL.PrintLine(2, '');
            PrintUL.PrintSeperator(2);
        END;
        //  Tender Declaration
        Transaction."Transaction No." := 0;
        TendDeclEntry.SETCURRENTKEY("Statement Code", "Z-Report ID", "Tender Type", "Currency Code", "Card No.");
        TendDeclEntry.SETRANGE("Statement Code", SCode);
        TendDeclEntry.SETRANGE("Z-Report ID", '');

        IF Store."Tend. Decl. Calculation" = Store."Tend. Decl. Calculation"::Sum THEN BEGIN
            BufferTendDeclEntry;
            IF TendDeclEntry.FIND('-') THEN
                Transaction."Transaction No." := TendDeclEntry."Transaction No.";
        END ELSE BEGIN
            IF TendDeclEntry.FIND('-') THEN
                REPEAT
                    IF TendDeclEntry."Transaction No." > Transaction."Transaction No." THEN
                        Transaction.GET(TendDeclEntry."Store No.", TendDeclEntry."POS Terminal No.", TendDeclEntry."Transaction No.")
                UNTIL TendDeclEntry.NEXT = 0;
        END;

        IF Transaction."Transaction No." <> 0 THEN BEGIN
            CLEAR(TendDeclEntry);
            LocalTotal := 0;
            IF Store."Tend. Decl. Calculation" = Store."Tend. Decl. Calculation"::Last THEN BEGIN
                TendDeclEntry.SETCURRENTKEY("Store No.", "POS Terminal No.", "Transaction No.");
                TendDeclEntry.SETRANGE("Store No.", Transaction."Store No.");
                TendDeclEntry.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
                TendDeclEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
                BufferTendDeclEntry;
            END;
            TempTendDeclEntry.SETFILTER("Currency Code", '=%1', '');
            Transaction."Gross Amount" := -LocalTotal;
            TempTendDeclEntry.SETFILTER("Currency Code", '<>%1', '');
        END;

        //contenido cortes
        vVentasGravadasTotales := 0;
        vImpuestoIVATotales := 0;
        vTotalGravadoTotales := 0;
        vVentasExentasTotales := 0;
        vVentasNoSujetasTotales := 0;
        vVentasTotalesTotales := 0;
        vIVAPercibidoTotales := 0;
        vIVAPercibidoDevTotales := 0;
        vIVARetenidoTotales := 0;
        vCESCTotales := 0;

        //ENCABEZADO PARA EL TIPO DE COMPROBANTE
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := '1- Ticket';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

        Transaction2.RESET;
        Transaction2.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
        Transaction2.SETRANGE(Transaction2."POS Terminal No.", Terminal."No.");
        Transaction2.SETRANGE("Statement Code", SCode);
        Transaction2.SETRANGE("Z-Report ID", '');
        Transaction2.SETRANGE("Transaction Type", Transaction2."Transaction Type"::Sales);
        Transaction2.SETFILTER("Entry Status", '%1|%2|%3', Transaction2."Entry Status"::" ", Transaction2."Entry Status"::Posted, Transaction2."Entry Status"::Voided);
        Transaction2.SETRANGE("FSN No. Serie NCF", Terminal."FSN No. Serie NCF Ticket");
        IF Transaction2.FINDFIRST THEN BEGIN
            rNoSeries.RESET;
            IF rNoSeries.GET(Terminal."FSN No. Serie NCF Ticket") THEN BEGIN
                rNoSeriesLn.RESET;
                rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
                IF rNoSeriesLn.FINDFIRST THEN BEGIN
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := 'Autorizacion: ' + UPPERCASE(rNoSeriesLn."FSN Autorization");
                    PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    //Imprimir el rango de ticket..
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := 'Del ' + rNoSeriesLn."Starting No.";

                    PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    DSTR1 := COPYSTR('#L######################################', 1);

                    Value[1] := 'al  ' + rNoSeriesLn."Ending No.";
                    PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
            END;

            FirstTicket := Transaction2."FSN NCF";

            REPEAT
                CLEAR(Venta);
                CLEAR(Iva);
                CLEAR(vTotal);
                rSalesEntry.SETRANGE("Store No.", Transaction2."Store No.");
                rSalesEntry.SETRANGE("POS Terminal No.", Transaction2."POS Terminal No.");
                rSalesEntry.SETRANGE("Transaction No.", Transaction2."Transaction No.");
                IF rSalesEntry.FIND('-') THEN
                    REPEAT
                        IF rSalesEntry."FSN Remission No." <> '' THEN BEGIN
                            Venta += -(rSalesEntry."Net Amount");
                            Iva += -(rSalesEntry."VAT Amount");
                            vTotal += -(rSalesEntry."Net Amount") + -(rSalesEntry."VAT Amount");
                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += -(rSalesEntry."Net Amount");
                                    TotalIva += -(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += -(rSalesEntry."Net Amount");
                                    TotalIvaNcr += -(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += -(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += -(rSalesEntry."Net Amount");
                                END;
                            END;
                        END ELSE BEGIN
                            Venta += ABS(rSalesEntry."Net Amount");
                            Iva += ABS(rSalesEntry."VAT Amount");
                            vTotal += ABS(rSalesEntry."Net Amount") + ABS(rSalesEntry."VAT Amount");
                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += ABS(rSalesEntry."Net Amount");
                                    TotalIva += ABS(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += ABS(rSalesEntry."Net Amount");
                                    TotalIvaNcr += ABS(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += ABS(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += ABS(rSalesEntry."Net Amount");
                                END;
                            END;
                        END;
                    UNTIL rSalesEntry.NEXT = 0;
                LastTicket := Transaction2."FSN NCF";
            UNTIL Transaction2.NEXT = 0;
        END;
        IF (FirstTicket <> '') OR (LastTicket <> '') THEN BEGIN
            //Del No.
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := 'Del No.: ' + FirstTicket;
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            //Al No.
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := 'Al No.: ' + LastTicket;
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        VentasG := VentasG - TotalVentNcr;

        //VENTAS GRAVADAS...
        DSTR1 := COPYSTR('#L##############         #R#############', 1);
        Value[1] := 'Ventas Gravadas:';
        Value[2] := '$' + FORMAT(VentasG, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        TotalIva := TotalIva - TotalIvaNcr;

        //IMPUESTO IVA...
        DSTR1 := COPYSTR('#L###########            #R#############', 1);
        Value[1] := 'Impuesto IVA:';
        Value[2] := '$' + FORMAT(TotalIva - vCESC, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //IMPUESTO CESC...
        DSTR1 := COPYSTR('#L############           #R#############', 1);
        Value[1] := 'Impuesto CESC:';
        Value[2] := '$' + FORMAT(vCESC, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Total Gravado...
        DSTR1 := COPYSTR('#L############           #R#############', 1);
        Value[1] := 'Total Gravado:';
        Value[2] := '$' + FORMAT(VentasG + TotalIva, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS EXENTAS...
        DSTR1 := COPYSTR('#L#############          #R#############', 1);
        Value[1] := 'Ventas Exentas:';
        Value[2] := '$' + FORMAT((VentasE - VentasEDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS NO SUJETAS...
        DSTR1 := COPYSTR('#L################       #R#############', 1);
        Value[1] := 'Ventas No Sujetas:';
        Value[2] := '$' + FORMAT((VentasNoSu - VentasNoSuDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS TOTALES
        DSTR1 := COPYSTR('#L#############          #R#############', 1);
        Value[1] := 'Ventas Totales:';
        Value[2] := '$' + FORMAT((VentasG + TotalIva + VentasE + VentasNoSu) - (VentasEDev + VentasNoSuDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        vVentasGravadasTotales := vVentasGravadasTotales + VentasG;
        vImpuestoIVATotales := vImpuestoIVATotales + TotalIva - vCESC;
        vCESCTotales := vCESCTotales + vCESC;
        vTotalGravadoTotales := vTotalGravadoTotales + (VentasG + TotalIva);
        vVentasExentasTotales := vVentasExentasTotales + (VentasE - VentasEDev);
        vVentasNoSujetasTotales := vVentasNoSujetasTotales + (VentasNoSu - VentasNoSuDev);
        vVentasTotalesTotales := vVentasTotalesTotales + ((VentasG + TotalIva + VentasE + VentasNoSu) - (VentasEDev + VentasNoSuDev));

        //LIMPIO LAS VARIABLES QUE MUESTRAN LOS TOTALES DE LAS VENTAS POR TIPO DE COMPROBANTES.
        CLEAR(FirstTicket);
        CLEAR(LastTicket);
        CLEAR(Venta);
        CLEAR(Iva);
        CLEAR(vTotal);
        CLEAR(VentasG);
        CLEAR(TotalIva);
        CLEAR(TotalVentNcr);
        CLEAR(TotalIvaNcr);
        CLEAR(VentasE);
        CLEAR(VentasNoSu);
        CLEAR(VentasEDev);
        CLEAR(VentasNoSuDev);
        CLEAR(vCESC);

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //ENCABEZADO PARA EL TIPO DE COMPROBANTE
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := '2- Comprobante de Crédito Fiscal';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

        //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
        //se agrego rango de facturas
        //BUSCO PRIMERO LOS NCF PARA CREDITO FISCALES
        Transaction2.RESET;
        Transaction2.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
        Transaction2.SETRANGE(Transaction2."POS Terminal No.", Terminal."No.");
        Transaction2.SETRANGE("Statement Code", SCode);
        Transaction2.SETRANGE("Z-Report ID", '');
        Transaction2.SETRANGE("Transaction Type", Transaction2."Transaction Type"::Sales);
        Transaction2.SETFILTER("Entry Status", '%1|%2|%3', Transaction2."Entry Status"::" ", Transaction2."Entry Status"::Posted, Transaction2."Entry Status"::Voided);
        Transaction2.SETRANGE("FSN No. Serie NCF", Terminal."FSN No. Serie Credito Fiscal");
        IF Transaction2.FINDFIRST THEN BEGIN
            rNoSeries.RESET;
            IF rNoSeries.GET(Terminal."FSN No. Serie Credito Fiscal") THEN BEGIN
                rNoSeriesLn.RESET;
                rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
                IF rNoSeriesLn.FINDFIRST THEN BEGIN
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := 'Autorizacion: ' + UPPERCASE(rNoSeriesLn."FSN Autorization");
                    DSTR1 := COPYSTR('#L#################  #R#################', 1);
                    Value[1] := 'Del ' + rNoSeriesLn."Starting No.";
                    Value[2] := 'al  ' + rNoSeriesLn."Ending No.";
                END;
            END;
            //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
            //se agrego rango de facturas
            FirstFactCrf := Transaction2."FSN NCF";
            vFirstFechaCref := Transaction2.Date;
            //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
            REPEAT
                CLEAR(Venta);
                CLEAR(Iva);
                CLEAR(vTotal);
                rSalesEntry.SETRANGE("Store No.", Transaction2."Store No.");
                rSalesEntry.SETRANGE("POS Terminal No.", Transaction2."POS Terminal No.");
                rSalesEntry.SETRANGE("Transaction No.", Transaction2."Transaction No.");
                IF rSalesEntry.FIND('-') THEN
                    REPEAT
                        IF rSalesEntry."FSN Remission No." <> '' THEN BEGIN
                            Venta += -(rSalesEntry."Net Amount");
                            Iva += -(rSalesEntry."VAT Amount");
                            vTotal += -(rSalesEntry."Net Amount") + -(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += -(rSalesEntry."Net Amount");
                                    TotalIva += -(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += -(rSalesEntry."Net Amount");
                                    TotalIvaNcr += -(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += -(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += -(rSalesEntry."Net Amount");
                                END;
                            END;
                        END ELSE BEGIN
                            Venta += ABS(rSalesEntry."Net Amount");
                            Iva += ABS(rSalesEntry."VAT Amount");
                            vTotal += ABS(rSalesEntry."Net Amount") + ABS(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += ABS(rSalesEntry."Net Amount");
                                    TotalIva += ABS(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += ABS(rSalesEntry."Net Amount");
                                    TotalIvaNcr += ABS(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += ABS(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += ABS(rSalesEntry."Net Amount");
                                END;
                            END;
                        END;
                    UNTIL rSalesEntry.NEXT = 0;
                //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                //se agrego rango de facturas
                LastFactCrf := Transaction2."FSN NCF";
                vLastFechaCref := Transaction2.Date;
                //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                IF NOT Transaction2."Sale Is Return Sale" THEN
                    Percepcion += ABS(Transaction2."FSN Perception Amount")
                ELSE
                    PercepcionDev += -(Transaction2."FSN Perception Amount");
            UNTIL Transaction2.NEXT = 0;
        END;

        //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
        //se agrego rango de facturas
        IF (FirstFactCrf <> '') OR (LastFactCrf <> '') THEN BEGIN
            rNoSeriesLn.RESET;
            rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
            IF rNoSeriesLn.FINDFIRST THEN
                REPEAT
                    IF ((rNoSeriesLn."Starting No." <= FirstFactCrf) AND (rNoSeriesLn."Ending No." >= FirstFactCrf)) AND
                    ((rNoSeriesLn."Starting Date" <= vFirstFechaCref) AND (rNoSeriesLn."Last Date Used" >= vFirstFechaCref)) THEN
                        vFirstFactCredAut := UPPERCASE(rNoSeriesLn.Series);
                    IF ((rNoSeriesLn."Starting No." <= LastFactCrf) AND (rNoSeriesLn."Ending No." >= LastFactCrf)) AND
                    ((rNoSeriesLn."Starting Date" <= vLastFechaCref) AND (rNoSeriesLn."Last Date Used" >= vLastFechaCref)) THEN
                        vLastFactCredAut := UPPERCASE(rNoSeriesLn.Series);
                UNTIL rNoSeriesLn.NEXT = 0;
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := 'Del No.: ' + vFirstFactCredAut + ' ' + FirstFactCrf;
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := 'Al No.: ' + vLastFactCredAut + ' ' + LastFactCrf;
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;

        //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        VentasG := VentasG - TotalVentNcr;
        //VENTAS GRAVADAS...
        DSTR1 := COPYSTR('#L##############    #R##################', 1);
        Value[1] := 'Ventas Gravadas:';
        Value[2] := '$' + FORMAT(VentasG, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        TotalIva := TotalIva - TotalIvaNcr;
        //IMPUESTO IVA...
        DSTR1 := COPYSTR('#L###########       #R##################', 1);
        Value[1] := 'Impuesto IVA:';
        Value[2] := '$' + FORMAT(TotalIva - vCESC, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        //IMPUESTO CESC...
        DSTR1 := COPYSTR('#L############           #R#############', 1);
        Value[1] := 'Impuesto CESC:';
        Value[2] := '$' + FORMAT(vCESC, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        //Total Gravado...
        DSTR1 := COPYSTR('#L############      #R##################', 1);
        Value[1] := 'Total Gravado:';
        Value[2] := '$' + FORMAT(VentasG + TotalIva, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        CLEAR(Percibido);
        //PERCEPCION...
        DSTR1 := COPYSTR('#L################# #R##################', 1);
        Value[1] := '(+) IVA Percibido:';
        Value[2] := '$' + FORMAT((Percepcion), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        //VENTAS EXENTAS...
        DSTR1 := COPYSTR('#L#############     #R##################', 1);
        Value[1] := 'Ventas Exentas:';
        Value[2] := '$' + FORMAT((VentasE), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        //VENTAS NO SUJETAS...
        DSTR1 := COPYSTR('#L################  #R##################', 1);
        Value[1] := 'Ventas No Sujetas:';
        Value[2] := '$' + FORMAT((VentasNoSu), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS TOTALES
        DSTR1 := COPYSTR('#L#############     #R##################', 1);
        Value[1] := 'Ventas Totales:';
        Value[2] := '$' + FORMAT((VentasG + TotalIva + VentasE + VentasNoSu + Percepcion), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        vVentasGravadasTotales := vVentasGravadasTotales + VentasG;

        vImpuestoIVATotales := vImpuestoIVATotales + TotalIva - vCESC;
        vCESCTotales := vCESCTotales + vCESC;
        vTotalGravadoTotales := vTotalGravadoTotales + (VentasG + TotalIva);
        vVentasExentasTotales := vVentasExentasTotales + (VentasE - VentasEDev);
        vVentasNoSujetasTotales := vVentasNoSujetasTotales + (VentasNoSu - VentasNoSuDev);
        vVentasTotalesTotales := vVentasTotalesTotales + ((VentasG + TotalIva + VentasE + VentasNoSu + (Percepcion - PercepcionDev)) - (VentasEDev + VentasNoSuDev));
        vIVAPercibidoTotales := vIVAPercibidoTotales + (Percepcion);

        //LIMPIO LAS VARIABLES QUE MUESTRAN LOS TOTALES DE LAS VENTAS POR TIPO DE COMPROBANTES.
        CLEAR(Venta);
        CLEAR(Iva);
        CLEAR(vTotal);
        CLEAR(VentasG);
        CLEAR(TotalIva);
        CLEAR(TotalVentNcr);
        CLEAR(TotalIvaNcr);
        CLEAR(VentasE);
        CLEAR(VentasNoSu);
        CLEAR(VentasEDev);
        CLEAR(VentasNoSuDev);
        CLEAR(Retencion);
        CLEAR(Percepcion);
        CLEAR(vCESC);

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        //ENCABEZADO PARA EL TIPO DE COMPROBANTE
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := '3- Nota de Crédito';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
        //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
        //se agrego rango de facturas
        Transaction2.RESET;
        Transaction2.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
        Transaction2.SetRange(Transaction2."POS Terminal No.", Terminal."No.");
        Transaction2.SETRANGE("Statement Code", SCode);
        Transaction2.SETRANGE("Z-Report ID", '');
        Transaction2.SETRANGE("Transaction Type", Transaction2."Transaction Type"::Sales);

        Transaction2.SETFILTER("Entry Status", '%1|%2|%3', Transaction2."Entry Status"::" ", Transaction2."Entry Status"::Posted, Transaction2."Entry Status"::Voided);
        Transaction2.SETRANGE("FSN No. Serie NCF", Terminal."FSN No. Serie Nota de Credito");
        IF Transaction2.FINDFIRST THEN BEGIN
            rNoSeries.RESET;
            IF rNoSeries.GET(Terminal."FSN No. Serie Nota de Credito") THEN BEGIN
                rNoSeriesLn.RESET;
                rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
                IF rNoSeriesLn.FINDFIRST THEN BEGIN
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := 'Autorizacion: ' + UPPERCASE(rNoSeriesLn."FSN Autorization");
                    DSTR1 := COPYSTR('#L#################  #R#################', 1);
                    Value[1] := 'Del ' + rNoSeriesLn."Starting No.";
                    Value[2] := 'al  ' + rNoSeriesLn."Ending No.";
                END;
            END;
            //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
            //se agrego rango de facturas
            FirstFactCrfDev := Transaction2."FSN NCF";
            vFirstFechaNocre := Transaction2.Date;
            //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda

            REPEAT
                CLEAR(Venta);
                CLEAR(Iva);
                CLEAR(vTotal);
                rSalesEntry.SETRANGE("Store No.", Transaction2."Store No.");
                rSalesEntry.SETRANGE("POS Terminal No.", Transaction2."POS Terminal No.");
                rSalesEntry.SETRANGE("Transaction No.", Transaction2."Transaction No.");
                IF rSalesEntry.FIND('-') THEN
                    REPEAT
                        IF rSalesEntry."FSN Remission No." <> '' THEN BEGIN
                            Venta += -(rSalesEntry."Net Amount");
                            Iva += -(rSalesEntry."VAT Amount");
                            vTotal += -(rSalesEntry."Net Amount") + -(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += -(rSalesEntry."Net Amount");
                                    TotalIva += -(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += -(rSalesEntry."Net Amount");
                                    TotalIvaNcr += -(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += -(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += -(rSalesEntry."Net Amount");
                                END;
                            END;
                        END ELSE BEGIN
                            Venta += ABS(rSalesEntry."Net Amount");
                            Iva += ABS(rSalesEntry."VAT Amount");
                            vTotal += ABS(rSalesEntry."Net Amount") + ABS(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += ABS(rSalesEntry."Net Amount");
                                    TotalIva += ABS(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += ABS(rSalesEntry."Net Amount");
                                    TotalIvaNcr += ABS(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += ABS(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += ABS(rSalesEntry."Net Amount");
                                END;
                            END;
                        END;
                    UNTIL rSalesEntry.NEXT = 0;
                //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                //se agrego rango de facturas
                LastFactCrfDev := Transaction2."FSN NCF";
                vLastFechaNocre := Transaction2.Date;
                //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                IF NOT Transaction2."Sale Is Return Sale" THEN
                    Percepcion += ABS(Transaction2."FSN Perception Amount")
                ELSE
                    PercepcionDev += -(Transaction2."FSN Perception Amount");
            UNTIL Transaction2.NEXT = 0;
        END;

        //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
        //se agrego rango de facturas
        IF (FirstFactCrfDev <> '') OR (LastFactCrfDev <> '') THEN BEGIN
            rNoSeriesLn.RESET;
            rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
            IF rNoSeriesLn.FINDFIRST THEN
                REPEAT
                    IF ((rNoSeriesLn."Starting No." <= FirstFactCrfDev) AND (rNoSeriesLn."Ending No." >= FirstFactCrfDev)) AND
                    ((rNoSeriesLn."Starting Date" <= vFirstFechaNocre) AND (rNoSeriesLn."Last Date Used" >= vFirstFechaNocre)) THEN
                        vFirstFactCredAut := UPPERCASE(rNoSeriesLn.Series);
                    IF ((rNoSeriesLn."Starting No." <= LastFactCrfDev) AND (rNoSeriesLn."Ending No." >= LastFactCrfDev)) AND
                    ((rNoSeriesLn."Starting Date" <= vLastFechaNocre) AND (rNoSeriesLn."Last Date Used" >= vLastFechaNocre)) THEN
                        vLastFactCredAut := UPPERCASE(rNoSeriesLn.Series);
                UNTIL rNoSeriesLn.NEXT = 0;
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := 'Del No.: ' + vFirstFactCredAut + ' ' + FirstFactCrfDev;
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := 'Al No.: ' + vLastFactCredAut + ' ' + LastFactCrfDev;
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;
        //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        VentasG := VentasG - TotalVentNcr;

        //VENTAS GRAVADAS...
        DSTR1 := COPYSTR('#L##############    #R##################', 1);
        Value[1] := 'Ventas Gravadas:';
        Value[2] := '$' + FORMAT(VentasG, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        TotalIva := TotalIva - TotalIvaNcr;

        //IMPUESTO IVA...
        DSTR1 := COPYSTR('#L###########       #R##################', 1);
        Value[1] := 'Impuesto IVA:';
        Value[2] := '$' + FORMAT(TotalIva, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Total Gravado...
        DSTR1 := COPYSTR('#L############      #R##################', 1);
        Value[1] := 'Total Gravado:';
        Value[2] := '$' + FORMAT(VentasG + TotalIva, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        CLEAR(Percibido);
        //PERCEPCION...
        DSTR1 := COPYSTR('#L################# #R##################', 1);
        Value[1] := '(+) IVA Percibido:';
        Value[2] := '$' + FORMAT((-PercepcionDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS EXENTAS...
        DSTR1 := COPYSTR('#L#############     #R##################', 1);
        Value[1] := 'Ventas Exentas:';
        Value[2] := '$' + FORMAT((VentasE - VentasEDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS NO SUJETAS...
        DSTR1 := COPYSTR('#L################  #R##################', 1);
        Value[1] := 'Ventas No Sujetas:';
        Value[2] := '$' + FORMAT((VentasNoSu - VentasNoSuDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS TOTALES
        DSTR1 := COPYSTR('#L#############     #R##################', 1);
        Value[1] := 'Ventas Totales:';
        Value[2] := '$' + FORMAT((VentasG + TotalIva + VentasE + VentasNoSu + (PercepcionDev + Percepcion)) - (VentasEDev + VentasNoSuDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        vVentasGravadasTotales := vVentasGravadasTotales + VentasG;
        vImpuestoIVATotales := vImpuestoIVATotales + TotalIva;
        vTotalGravadoTotales := vTotalGravadoTotales + (VentasG + TotalIva);
        vVentasExentasTotales := vVentasExentasTotales + (VentasE - VentasEDev);
        vVentasTotalesTotales := vVentasTotalesTotales + ((VentasG + TotalIva + VentasE + VentasNoSu + (PercepcionDev + Percepcion)) - (VentasEDev + VentasNoSuDev));
        vIVAPercibidoDevTotales := vIVAPercibidoDevTotales + (-PercepcionDev);

        //LIMPIO LAS VARIABLES QUE MUESTRAN LOS TOTALES DE LAS VENTAS POR TIPO DE COMPROBANTES.
        CLEAR(Venta);
        CLEAR(Iva);
        CLEAR(vTotal);
        CLEAR(VentasG);
        CLEAR(TotalIva);
        CLEAR(TotalVentNcr);
        CLEAR(TotalIvaNcr);
        CLEAR(VentasE);
        CLEAR(VentasNoSu);
        CLEAR(VentasEDev);
        CLEAR(VentasNoSuDev);
        CLEAR(Retencion);

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Solo aparece el valor total de documentos de devolución en detalle de factura de consumidor final
        //ENCABEZADO PARA EL TIPO DE COMPROBANTE
        //BUSCO PRIMERO LOS NCF PARA FACTURAS DE CONSUMIDORES FINALES
        Transaction2.RESET;
        Transaction2.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
        Transaction2.SETRANGE(Transaction2."POS Terminal No.", Terminal."No.");
        Transaction2.SETRANGE("Statement Code", SCode);
        Transaction2.SETRANGE("Z-Report ID", '');
        Transaction2.SETRANGE("Transaction Type", Transaction2."Transaction Type"::Sales);
        Transaction2.SETFILTER("Entry Status", '%1|%2', Transaction2."Entry Status"::" ", Transaction2."Entry Status"::Posted);
        Transaction2.SETRANGE("FSN No. Serie NCF", Terminal."FSN No. Serie Devolucion");
        IF Transaction2.FINDFIRST THEN BEGIN
            //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
            //se agrego rango de facturas
            FirstFactCfDev := Transaction2."FSN NCF";
            REPEAT
                CLEAR(Venta);
                CLEAR(Iva);
                CLEAR(vTotal);
                rSalesEntry.SETRANGE("Store No.", Transaction2."Store No.");
                rSalesEntry.SETRANGE("POS Terminal No.", Transaction2."POS Terminal No.");
                rSalesEntry.SETRANGE("Transaction No.", Transaction2."Transaction No.");
                IF rSalesEntry.FIND('-') THEN
                    REPEAT
                        IF rSalesEntry."FSN Remission No." <> '' THEN BEGIN
                            Venta += -(rSalesEntry."Net Amount");
                            Iva += -(rSalesEntry."VAT Amount");
                            vTotal += -(rSalesEntry."Net Amount") + -(rSalesEntry."VAT Amount");
                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += -(rSalesEntry."Net Amount");
                                    TotalIva += -(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += -(rSalesEntry."Net Amount");
                                    TotalIvaNcr += -(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += -(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += -(rSalesEntry."Net Amount");
                                END;
                            END;
                        END ELSE BEGIN
                            Venta += ABS(rSalesEntry."Net Amount");
                            Iva += ABS(rSalesEntry."VAT Amount");
                            vTotal += ABS(rSalesEntry."Net Amount") + ABS(rSalesEntry."VAT Amount");
                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += ABS(rSalesEntry."Net Amount");
                                    TotalIva += ABS(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += ABS(rSalesEntry."Net Amount");
                                    TotalIvaNcr += ABS(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += ABS(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += ABS(rSalesEntry."Net Amount");
                                END;
                            END;
                        END;
                    UNTIL rSalesEntry.NEXT = 0;

                //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                //se agrego rango de facturas
                LastFactCfDev := Transaction2."FSN NCF";

                IF NOT Transaction2."Sale Is Return Sale" THEN
                    Retencion += ABS(Transaction2."FSN Retention Amount")
                ELSE
                    RetencionDev += -(Transaction2."FSN Retention Amount");

            UNTIL Transaction2.NEXT = 0;
        END;

        //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
        //se agrego rango de facturas
        VentasG := VentasG - TotalVentNcr;
        TotalIva := TotalIva - TotalIvaNcr;
        //TOTAL documentos devolucion
        vTotalDocDevolucion := (VentasG + VentasE + VentasNoSu) - (VentasEDev + VentasNoSuDev);
        vTotalIvaDocDevolucion := TotalIva;

        vTotalRetencionDev := RetencionDev;
        VentasEDevDocDev := VentasEDev;
        vVentasExentasTotales := vVentasExentasTotales + (VentasE - VentasEDev);

        //LIMPIO LAS VARIABLES QUE MUESTRAN LOS TOTALES DE LAS VENTAS POR TIPO DE COMPROBANTES.
        CLEAR(Venta);
        CLEAR(Iva);
        CLEAR(vTotal);
        CLEAR(VentasG);
        CLEAR(TotalIva);
        CLEAR(TotalVentNcr);
        CLEAR(TotalIvaNcr);
        CLEAR(VentasE);
        CLEAR(VentasNoSu);
        CLEAR(VentasEDev);
        CLEAR(VentasNoSuDev);
        //ENCABEZADO PARA EL TIPO DE COMPROBANTE
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := '4- Factura De Consumidor Final';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

        //BUSCO PRIMERO LOS NCF PARA FACTURAS DE CONSUMIDORES FINALES
        Transaction2.RESET;
        Transaction2.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
        Transaction2.SETRANGE(Transaction2."POS Terminal No.", Terminal."No.");
        Transaction2.SETRANGE("Statement Code", SCode);
        Transaction2.SETRANGE("Z-Report ID", '');
        Transaction2.SETRANGE("Transaction Type", Transaction2."Transaction Type"::Sales);
        Transaction2.SETFILTER("Entry Status", '%1|%2|%3', Transaction2."Entry Status"::" ", Transaction2."Entry Status"::Posted, Transaction2."Entry Status"::Voided);
        Transaction2.SETRANGE("FSN No. Serie NCF", Terminal."FSN No. Serie NCF Cons. Final");
        IF Transaction2.FINDFIRST THEN BEGIN
            rNoSeries.RESET;
            IF rNoSeries.GET(Terminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                rNoSeriesLn.RESET;
                rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
                IF rNoSeriesLn.FINDFIRST THEN BEGIN
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := 'Autorizacion: ' + UPPERCASE(rNoSeriesLn."FSN Autorization");
                    DSTR1 := COPYSTR('#L#################  #R#################', 1);
                    Value[1] := 'Del ' + rNoSeriesLn."Starting No.";
                    Value[2] := 'al  ' + rNoSeriesLn."Ending No.";
                END;
            END;

            //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
            //se agrego rango de facturas
            FirstFactCf := Transaction2."FSN NCF";
            vFirstFechaFac := Transaction2.Date;
            REPEAT
                CLEAR(Venta);
                CLEAR(Iva);
                CLEAR(vTotal);
                rSalesEntry.SETRANGE("Store No.", Transaction2."Store No.");
                rSalesEntry.SETRANGE("POS Terminal No.", Transaction2."POS Terminal No.");
                rSalesEntry.SETRANGE("Transaction No.", Transaction2."Transaction No.");
                IF rSalesEntry.FIND('-') THEN
                    REPEAT
                        IF rSalesEntry."FSN Remission No." <> '' THEN BEGIN
                            Venta += -(rSalesEntry."Net Amount");
                            Iva += -(rSalesEntry."VAT Amount");
                            vTotal += -(rSalesEntry."Net Amount") + -(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += -(rSalesEntry."Net Amount");
                                    TotalIva += -(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += -(rSalesEntry."Net Amount");
                                    TotalIvaNcr += -(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += -(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += -(rSalesEntry."Net Amount");
                                END;
                            END;
                        END ELSE BEGIN
                            Venta += ABS(rSalesEntry."Net Amount");
                            Iva += ABS(rSalesEntry."VAT Amount");
                            vTotal += ABS(rSalesEntry."Net Amount") + ABS(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += ABS(rSalesEntry."Net Amount");
                                    TotalIva += ABS(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += ABS(rSalesEntry."Net Amount");
                                    TotalIvaNcr += ABS(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += ABS(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += ABS(rSalesEntry."Net Amount");
                                END;
                            END;
                        END;
                    UNTIL rSalesEntry.NEXT = 0;

                //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                //se agrego rango de facturas
                LastFactCf := Transaction2."FSN Correlative";
                vLastFechaFac := Transaction2.Date;
                IF NOT Transaction2."Sale Is Return Sale" THEN
                    Retencion += ABS(Transaction2."FSN Retention Amount")
                ELSE
                    RetencionDev += -(Transaction2."FSN Retention Amount");
            UNTIL Transaction2.NEXT = 0;
        END;

        //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
        //se agrego rango de facturas
        IF (FirstFactCf <> '') OR (LastFactCf <> '') THEN BEGIN
            rNoSeriesLn.RESET;
            rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
            IF rNoSeriesLn.FINDFIRST THEN
                REPEAT
                    IF ((rNoSeriesLn."Starting No." <= FirstFactCf) AND (rNoSeriesLn."Ending No." >= FirstFactCf)) AND
                    ((rNoSeriesLn."Starting Date" <= vFirstFechaFac) AND (rNoSeriesLn."Last Date Used" >= vFirstFechaFac)) THEN
                        vFirstFactCFAut := UPPERCASE(rNoSeriesLn.Series);
                    IF ((rNoSeriesLn."Starting No." <= LastFactCf) AND (rNoSeriesLn."Ending No." >= LastFactCf)) AND
                    ((rNoSeriesLn."Starting Date" <= vLastFechaFac) AND (rNoSeriesLn."Last Date Used" >= vLastFechaFac)) THEN
                        vLastFactCFAut := UPPERCASE(rNoSeriesLn.Series);
                UNTIL rNoSeriesLn.NEXT = 0;

            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := 'Del No.: ' + vFirstFactCFAut + ' ' + FirstFactCf;
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := 'Al No.: ' + vLastFactCFAut + ' ' + LastFactCf;
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;

        //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        VentasG := VentasG - TotalVentNcr + vTotalDocDevolucion + VentasEDevDocDev;

        //VENTAS GRAVADAS...
        DSTR1 := COPYSTR('#L##############    #R##################', 1);
        Value[1] := 'Ventas Gravadas:';
        Value[2] := '$' + FORMAT(VentasG, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        TotalIva := TotalIva - TotalIvaNcr + vTotalIvaDocDevolucion;
        //IMPUESTO IVA...
        DSTR1 := COPYSTR('#L###########       #R##################', 1);
        Value[1] := 'Impuesto IVA:';
        Value[2] := '$' + FORMAT(TotalIva - vCESC, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //IMPUESTO CESC...
        DSTR1 := COPYSTR('#L############           #R#############', 1);
        Value[1] := 'Impuesto CESC:';
        Value[2] := '$' + FORMAT(vCESC, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Total Gravado...
        DSTR1 := COPYSTR('#L############      #R##################', 1);
        Value[1] := 'Total Gravado:';
        Value[2] := '$' + FORMAT(VentasG + TotalIva, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //PERCEPCION...
        DSTR1 := COPYSTR('#L################# #R##################', 1);
        Value[1] := '(-) IVA Retenido:';
        Value[2] := '$' + FORMAT((Retencion - vTotalRetencionDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS EXENTAS...
        DSTR1 := COPYSTR('#L#############     #R##################', 1);
        Value[1] := 'Ventas Exentas:';
        Value[2] := '$' + FORMAT((VentasE - VentasEDev - VentasEDevDocDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS NO SUJETAS...
        DSTR1 := COPYSTR('#L################  #R##################', 1);
        Value[1] := 'Ventas No Sujetas:';
        Value[2] := '$' + FORMAT((VentasNoSu - VentasNoSuDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //TOTAL DOCUMENTO DEVOLUCION
        //VENTAS TOTALES
        DSTR1 := COPYSTR('#L#############     #R##################', 1);
        Value[1] := 'Ventas Totales:';
        Value[2] := '$' + FORMAT((VentasG + TotalIva + VentasE + VentasNoSu) - (VentasEDev + VentasNoSuDev + (Retencion - RetencionDev) + VentasEDevDocDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        vVentasGravadasTotales := vVentasGravadasTotales + VentasG;
        vImpuestoIVATotales := vImpuestoIVATotales + TotalIva - vCESC;
        vCESCTotales := vCESCTotales + vCESC;
        vTotalGravadoTotales := vTotalGravadoTotales + (VentasG + TotalIva);
        vVentasExentasTotales := vVentasExentasTotales + (VentasE - VentasEDev);
        vVentasNoSujetasTotales := vVentasNoSujetasTotales + (VentasNoSu - VentasNoSuDev);
        vVentasTotalesTotales := vVentasTotalesTotales + ((VentasG + TotalIva + VentasE + VentasNoSu) - (VentasEDev + VentasNoSuDev + (Retencion - RetencionDev) + VentasEDevDocDev));
        vIVARetenidoTotales := vIVARetenidoTotales + (Retencion - RetencionDev);
        //LIMPIO LAS VARIABLES QUE MUESTRAN LOS TOTALES DE LAS VENTAS POR TIPO DE COMPROBANTES.
        CLEAR(Venta);
        CLEAR(Iva);
        CLEAR(vTotal);
        CLEAR(VentasG);
        CLEAR(TotalIva);
        CLEAR(TotalVentNcr);
        CLEAR(TotalIvaNcr);
        CLEAR(VentasE);
        CLEAR(VentasNoSu);
        CLEAR(VentasEDev);
        CLEAR(VentasNoSuDev);
        CLEAR(vTotalDocDevolucion);

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := 'VENTAS TOTALES';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS GRAVADAS TOTALES
        DSTR1 := COPYSTR('#L###################### #R#############', 1);
        Value[1] := 'Ventas Gravadas:';
        Value[2] := '$' + FORMAT(vVentasGravadasTotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //IMPUESTO IVA TOTALES
        DSTR1 := COPYSTR('#L###################### #R#############', 1);
        Value[1] := 'Impuesto IVA:';
        Value[2] := '$' + FORMAT(vImpuestoIVATotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //IMPUESTO CESC TOTALES
        DSTR1 := COPYSTR('#L###################### #R#############', 1);
        Value[1] := 'Impuesto CESC:';
        Value[2] := '$' + FORMAT(vCESCTotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //TOTAL GRAVADO TOTALES
        DSTR1 := COPYSTR('#L###################### #R#############', 1);
        Value[1] := 'Total Gravado:';
        Value[2] := '$' + FORMAT(vTotalGravadoTotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS EXENTAS TOTALES
        DSTR1 := COPYSTR('#L###################### #R#############', 1);
        Value[1] := 'Ventas Exentas:';
        Value[2] := '$' + FORMAT(vVentasExentasTotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS NO SUJETAS TOTALES
        DSTR1 := COPYSTR('#L###################### #R#############', 1);
        Value[1] := 'Ventas No Sujetas:';
        Value[2] := '$' + FORMAT(vVentasNoSujetasTotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //IVA PERCIBIDO TOTALES
        DSTR1 := COPYSTR('#L###################### #R#############', 1);
        Value[1] := '(+) IVA Percebido:';
        Value[2] := '$' + FORMAT(vIVAPercibidoTotales - vIVAPercibidoDevTotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //IVA RETENIDO TOTALES
        DSTR1 := COPYSTR('#L###################### #R#############', 1);
        Value[1] := '(-) IVA Retenido:';
        Value[2] := '$' + FORMAT(vIVARetenidoTotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS TOTALES TOTALES
        DSTR1 := COPYSTR('#L###################### #R#############', 1);
        Value[1] := 'Ventas Totales:';
        Value[2] := '$' + FORMAT(vVentasTotalesTotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //TOTAL DEVOLUCIONES
        //ENCABEZADO PARA EL TIPO DE COMPROBANTE
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := 'DEVOLUCIONES';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
        Transaction2.RESET;
        Transaction2.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
        Transaction2.SETRANGE(Transaction2."POS Terminal No.", POSSESSION.TerminalNo());
        Transaction2.SETRANGE("Statement Code", SCode);
        Transaction2.SETRANGE("Z-Report ID", '');
        Transaction2.SETRANGE("Transaction Type", Transaction2."Transaction Type"::Sales);
        Transaction2.SETFILTER("Entry Status", '%1|%2', Transaction2."Entry Status"::" ", Transaction2."Entry Status"::Posted);
        Transaction2.SETRANGE("Sale Is Return Sale", TRUE);
        vNoDevoluciones := 0;
        IF Transaction2.FINDFIRST THEN BEGIN
            REPEAT
                vNoDevoluciones := (vNoDevoluciones + 1);
                CLEAR(Venta);
                CLEAR(Iva);
                CLEAR(vTotal);
                rSalesEntry.SETRANGE("Store No.", Transaction2."Store No.");
                rSalesEntry.SETRANGE("POS Terminal No.", Transaction2."POS Terminal No.");
                rSalesEntry.SETRANGE("Transaction No.", Transaction2."Transaction No.");
                IF rSalesEntry.FIND('-') THEN
                    REPEAT
                        IF rSalesEntry."FSN Remission No." <> '' THEN BEGIN
                            Venta += -(rSalesEntry."Net Amount");
                            Iva += -(rSalesEntry."VAT Amount");
                            vTotal += -(rSalesEntry."Net Amount") + -(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += -(rSalesEntry."Net Amount");
                                    TotalIva += -(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += -(rSalesEntry."Net Amount");
                                    TotalIvaNcr += -(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += -(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += -(rSalesEntry."Net Amount");
                                END;
                            END;
                        END ELSE BEGIN
                            Venta += ABS(rSalesEntry."Net Amount");
                            Iva += ABS(rSalesEntry."VAT Amount");
                            vTotal += ABS(rSalesEntry."Net Amount") + ABS(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += ABS(rSalesEntry."Net Amount");
                                    TotalIva += ABS(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += ABS(rSalesEntry."Net Amount");
                                    TotalIvaNcr += ABS(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += ABS(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += ABS(rSalesEntry."Net Amount");
                                END;
                            END;
                        END;
                    UNTIL rSalesEntry.NEXT = 0;
            UNTIL Transaction2.NEXT = 0;
        END;

        //DEVOLUCIONES...
        DSTR1 := COPYSTR('#L#################### #L#############', 1);
        Value[1] := 'Cantidad devoluciones:';
        Value[2] := FORMAT(vNoDevoluciones);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        VentasG := VentasG - TotalVentNcr;
        TotalIva := TotalIva - TotalIvaNcr;

        //VENTAS TOTALES
        DSTR1 := COPYSTR('#L################### #R################', 1);
        Value[1] := 'Devoluciones Totales:';
        Value[2] := '$' + FORMAT((VentasG + TotalIva + VentasE + VentasNoSu) - (VentasEDev + VentasNoSuDev) + vTotalRetencionDev - vIVAPercibidoDevTotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //LIMPIO LAS VARIABLES QUE MUESTRAN LOS TOTALES DE LAS VENTAS POR TIPO DE COMPROBANTES.
        CLEAR(FirstTicket);
        CLEAR(LastTicket);
        CLEAR(Venta);
        CLEAR(Iva);
        CLEAR(vTotal);
        CLEAR(VentasG);
        CLEAR(TotalIva);
        CLEAR(TotalVentNcr);
        CLEAR(TotalIvaNcr);
        CLEAR(VentasE);
        CLEAR(VentasNoSu);
        CLEAR(VentasEDev);
        CLEAR(VentasNoSuDev);

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        //contenido cortes fin
        vIVAS := vIVAPercibidoTotales - vIVAPercibidoDevTotales - vIVARetenidoTotales;
        //Se movio al final de los reportes
        CLEAR(PaymEntry);
        PaymEntry.SETCURRENTKEY("Statement Code", "Z-Report ID", "Tender Type", "Currency Code", "Card No.");
        PaymEntry.SETRANGE("Statement Code", SCode);
        PaymEntry.SETRANGE("Z-Report ID", '');
        PaymTrans3.COPYFILTERS(PaymEntry);

        TenderType.SETCURRENTKEY("Store No.");
        TenderType.SETRANGE("Store No.", Globals.StoreNo);
        TenderType.SETFILTER(TenderType."Function", '<>%1', TenderType."Function"::"Tender Remove/Float");
        TenderType.SETRANGE("Foreign Currency", TRUE);
        LocalTotal := 0;

        TenderType.SETRANGE("Foreign Currency");
        TenderType.SETRANGE(TenderType."Function", TenderType."Function"::"Tender Remove/Float");
        TenderType.SETRANGE(TenderType."Function", TenderType."Function"::"Tender Remove/Float");
        IF TenderType.FIND('-') THEN BEGIN
            PrintUL.PrintSeperator(2);
            REPEAT
                FOR lSafeType := 0 TO 3 DO BEGIN
                    NoOfLines := 0;
                    TotalSafeType := 0;
                    PaymEntry.SETRANGE("Safe type", lSafeType);
                    PaymEntry.SETRANGE("Currency Code");
                    PaymEntry.SETRANGE("Card No.");
                    PaymEntry.SETRANGE("Tender Type", TenderType.Code);
                    IF PaymEntry.FIND('-') THEN
                        REPEAT
                            NoOfLines := NoOfLines + 1;
                            Transaction.GET(PaymEntry."Store No.", PaymEntry."POS Terminal No.", PaymEntry."Transaction No.");
                            IF PaymEntry."Amount Tendered" > 0 THEN BEGIN
                                RemoveTotal := RemoveTotal + PaymEntry."Amount Tendered";
                            END
                            ELSE BEGIN
                                FloatTotal := FloatTotal + PaymEntry."Amount Tendered";
                            END;
                            TotalSafeType := TotalSafeType + PaymEntry."Amount Tendered";
                            LineFound := TRUE;
                        UNTIL PaymEntry.NEXT = 0;
                END;
            UNTIL TenderType.NEXT = 0;
        END;
        PaymEntry.SETRANGE("Safe type");

        IF FloatTotal <> 0 THEN BEGIN
            DSTR1 := '#C######################################';
            Value[1] := 'INGRESOS';
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            DSTR1 := '#L#############     #R##################';
            Value[1] := 'DESCRIPCIÓN';
            Value[2] := 'MONTO';
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            DSTR1 := '#L##############    #R##################';
            Value[1] := Text009 + ':';
            Value[2] := POSFunctions.FormatAmount(FloatTotal);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            DSTR1 := COPYSTR('                     ', 1);
            Value[1] := '';
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            DSTR1 := '#L######################### #R##########';
        END;

        DSTR1 := '#C######################################';
        Value[1] := 'RETIROS';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

        DSTR1 := '#L#############     #R##################';
        Value[1] := 'DESCRIPCIÓN';
        Value[2] := 'MONTO';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        TenderType.RESET;
        TenderType.SETRANGE("Store No.", Store."No.");
        TenderType.SETFILTER(TenderType.Code, '%1|%2', '1', '2');
        IF TenderType.FIND('-') THEN
            REPEAT
                PaymEntry.SETRANGE("Tender Type", TenderType.Code);
                PaymEntry.SetRange("POS Terminal No.", POSSESSION.TerminalNo());
                PaymEntry.SETRANGE("Z-Report ID", '');
                PaymEntry.SETFILTER("Amount Tendered", '<%1', 0);
                PaymEntry.SETFILTER("Safe type", '=%1', PaymEntry."Safe type"::Bank);
                IF PaymEntry.FIND('-') THEN
                    REPEAT
                        rTransaction.RESET;
                        rTransaction.SETRANGE("Receipt No.", PaymEntry."Receipt No.");
                        rTransaction.FINDFIRST;
                        IF (rTransaction."Transaction Type" = rTransaction."Transaction Type"::"Remove Tender") OR
                        (rTransaction."Transaction Type" = rTransaction."Transaction Type"::"Tender Decl.") THEN BEGIN
                            IF (TenderType.Code = '1') THEN
                                vEfectivoRetirado := vEfectivoRetirado + (-PaymEntry."Amount Tendered")
                            ELSE
                                vChequeRetirado := vChequeRetirado + (-PaymEntry."Amount Tendered");
                        END;
                    UNTIL PaymEntry.NEXT = 0;
            UNTIL TenderType.NEXT = 0;

        IF (vEfectivoRetirado >= 0) THEN BEGIN
            DSTR1 := '#L###################### #R#############';
            Value[1] := TextEfectivoRetirado;
            Value[2] := POSFunctions.FormatAmount(vEfectivoRetirado);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;
        IF (vChequeRetirado >= 0) THEN BEGIN
            DSTR1 := '#L###################### #R#############';
            Value[1] := TextChequeRetirado;
            Value[2] := POSFunctions.FormatAmount(vChequeRetirado);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        Value[1] := '';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        DSTR1 := '#L######################### #R##########';

        //efectivo a retirar
        //Efectivo y cheque a retirar
        TenderType.RESET;
        TenderType.SETRANGE("Store No.", Store."No.");
        TenderType.SETFILTER(TenderType.Code, '%1|%2', '1', '2');
        IF TenderType.FIND('-') THEN
            REPEAT
                Transaction4.RESET;
                Transaction4.SETRANGE("Transaction Type", Transaction4."Transaction Type"::Sales);
                Transaction4.SETRANGE(Transaction4."POS Terminal No.", Terminal."No.");
                Transaction4.SETRANGE("Z-Report ID", '');
                Transaction4.SETRANGE("Income/Exp. Amount", 0.0);
                IF Transaction4.FINDSET THEN
                    REPEAT
                        PaymEntry.RESET;
                        PaymEntry.SETRANGE("Z-Report ID", '');
                        PaymEntry.SETRANGE("Tender Type", TenderType.Code);
                        PaymEntry.SETFILTER("Safe type", '<>%1&<>%2', PaymEntry."Safe type"::Bank, PaymEntry."Safe type"::Safe);
                        PaymEntry.SETRANGE("Receipt No.", Transaction4."Receipt No.");
                        IF PaymEntry.FIND('-') THEN
                            REPEAT
                                IF (TenderType.Code = '1') THEN
                                    vEfectivoTotal := vEfectivoTotal + PaymEntry."Amount Tendered"
                                ELSE
                                    vChequeTotal := vChequeTotal + PaymEntry."Amount Tendered";
                            UNTIL PaymEntry.NEXT = 0;
                    UNTIL Transaction4.NEXT = 0;
            UNTIL TenderType.NEXT = 0;
        rTransSafeEntry.RESET;
        rTransSafeEntry.SETRANGE("Safe Type", rTransSafeEntry."Safe Type"::Safe);
        rTransSafeEntry.SETRANGE("Tender Type", '1');
        IF rTransSafeEntry.FIND('-') THEN BEGIN
            rTransSafeEntry.CALCSUMS("Amount Tendered");
            vCofreEfectivo := rTransSafeEntry."Amount Tendered";
        END;
        rTransSafeEntry.RESET;
        rTransSafeEntry.SETRANGE("Safe Type", rTransSafeEntry."Safe Type"::Safe);
        rTransSafeEntry.SETRANGE("Tender Type", '2');
        IF rTransSafeEntry.FIND('-') THEN BEGIN
            rTransSafeEntry.CALCSUMS("Amount Tendered");
            vCofreCheque := rTransSafeEntry."Amount Tendered";
        END;

        IF (vEfectivoTotal - ABS(vEfectivoRetirado) >= 0) THEN BEGIN
            DSTR1 := '#L########################## #R#########';
            Value[1] := TextEfectivoARetirar;
            //se quito el ivaretenido
            //se quito el ivapercibido
            Value[2] := POSFunctions.FormatAmount(vEfectivoTotal - ABS(vEfectivoRetirado));
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;
        IF (vChequeTotal - ABS(vChequeRetirado) >= 0) THEN BEGIN
            DSTR1 := '#L########################## #R#########';
            Value[1] := TextChequeARetirar;
            Value[2] := POSFunctions.FormatAmount(vChequeTotal - ABS(vChequeRetirado));
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;

        //mostrar cofre
        IF TRUE THEN BEGIN
            DSTR1 := '#L########################## #R#########';
            Value[1] := 'Cofre Efectivo';
            Value[2] := POSFunctions.FormatAmount(vCofreEfectivo);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            DSTR1 := '#L########################## #R#########';
            Value[1] := 'Cofre Cheque';
            Value[2] := POSFunctions.FormatAmount(vCofreCheque);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;

        CLEAR(PaymEntry);
        PaymEntry.SETCURRENTKEY("Statement Code", "Z-Report ID", "Tender Type", "Currency Code", "Card No.");
        PaymEntry.SETRANGE("Statement Code", SCode);
        PaymEntry.SETRANGE("Z-Report ID", '');
        PaymTrans3.COPYFILTERS(PaymEntry);

        TenderType.RESET;
        TenderType.SETCURRENTKEY("Store No.");
        TenderType.SETRANGE("Store No.", Globals.StoreNo);
        TenderType.SETFILTER(TenderType."Function", '<>%1', TenderType."Function"::"Tender Remove/Float");
        TenderType.SETRANGE("Foreign Currency", FALSE);
        LocalTotal := 0;
        LocalTotal := 0;

        PrintUL.PrintSeperator(2);
        PrintXZLines();
        Transaction."Transaction No." := 0;
        TendDeclEntry.SETCURRENTKEY("Statement Code", "Z-Report ID", "Tender Type", "Currency Code", "Card No.");
        TendDeclEntry.SETRANGE("Statement Code", SCode);
        TendDeclEntry.SETRANGE("Z-Report ID", '');
        IF Store."Tend. Decl. Calculation" = Store."Tend. Decl. Calculation"::Sum THEN BEGIN
            BufferTendDeclEntry;
            IF TendDeclEntry.FIND('-') THEN
                Transaction."Transaction No." := TendDeclEntry."Transaction No.";
        END
        ELSE BEGIN
            IF TendDeclEntry.FIND('-') THEN
                REPEAT
                    IF TendDeclEntry."Transaction No." > Transaction."Transaction No." THEN
                        Transaction.GET(TendDeclEntry."Store No.", TendDeclEntry."POS Terminal No.", TendDeclEntry."Transaction No.")
                UNTIL TendDeclEntry.NEXT = 0;
        END;

        IF Transaction."Transaction No." <> 0 THEN BEGIN
            PrintUL.PrintLine(2, PrintUL.FormatLine(Text112, FALSE, TRUE, FALSE, FALSE));
            CLEAR(TendDeclEntry);
            LocalTotal := 0;
            IF Store."Tend. Decl. Calculation" = Store."Tend. Decl. Calculation"::Last THEN BEGIN
                TendDeclEntry.SETCURRENTKEY("Store No.", "POS Terminal No.", "Transaction No.");
                TendDeclEntry.SETRANGE("Store No.", Transaction."Store No.");
                TendDeclEntry.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
                TendDeclEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
                BufferTendDeclEntry;
            END;
            TempTendDeclEntry.SETFILTER("Currency Code", '=%1', '');
            PrintTenderDeclLines;
            Transaction."Gross Amount" := -LocalTotal;
            PrintTotal(Transaction, 2, 0);
            PrintUL.PrintLine(2, '');
            TempTendDeclEntry.SETFILTER("Currency Code", '<>%1', '');
            PrintTenderDeclLines;
        END;

        // Sales and Discount Totals
        AmountTotal := 0;
        DiscoutAmount := 0;//20240325
        // Sales and Discount Totals
        Transaction.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
        Transaction.SETRANGE(Transaction."POS Terminal No.", POSSESSION.TerminalNo());
        Transaction.SETRANGE("Statement Code", SCode);
        Transaction.SETRANGE("Z-Report ID", '');
        Transaction.SETRANGE("Transaction Type", Transaction."Transaction Type"::Sales);
        Transaction.SETFILTER("Entry Status", '%1|%2', Transaction."Entry Status"::" ", Transaction."Entry Status"::Posted);
        //Transaction.CALCSUMS("Gross Amount", "Discount Amount", "Total Discount", Rounded, "No. of Items");
        IF Transaction.FINd('-') THEN BEGIN
            REPEAT
                DiscoutAmount := DiscoutAmount + Transaction."Discount Amount";
                PaymentFilt.RESET;
                PaymentFilt.SETRANGE("Store No.", Transaction."Store No.");
                PaymentFilt.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
                PaymentFilt.SETRANGE("Transaction No.", Transaction."Transaction No.");
                //PaymentFilt.SETRANGE("Tender Type", TenderType.Code);
                PaymentFilt.SETRANGE(PaymentFilt."Safe type", PaymentFilt."Safe type"::" ");
                PaymentFilt.SETRANGE("Receipt No.", Transaction."Receipt No.");
                IF PaymentFilt.FIND('-') THEN
                    repeat
                        AmountTotal := AmountTotal + PaymentFilt."Amount Tendered";
                    until PaymentFilt.Next() = 0;
            until Transaction.Next() = 0;
        END;

        //Imprimir Linea en blanco...
        AmountTotal := 0;
        DiscoutAmount := 0;//20240325
        DSTR1 := COPYSTR('                     ', 1);
        Value[1] := '';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        DSTR1 := '#L######################### #R##########';
        Value[1] := 'Total Medios de Pago:';
        Value[2] := POSFunctions.FormatAmount(AmountTotal + vIVAS);
        //Value[2] := POSFunctions.FormatAmount(-Transaction."Gross Amount" + Transaction.Rounded + vIVAS);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        PrintUL.PrintSeperator(2);

        DSTR1 := '#L######################### #R##########';
        Value[2] := POSFunctions.FormatAmount(AmountTotal + DiscoutAmount + vIVAS);
        //Value[2] := POSFunctions.FormatAmount(-Transaction."Gross Amount" + Transaction."Discount Amount" + vIVAS);
        Value[1] := 'Ventas Brutas:';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        Value[2] := POSFunctions.FormatAmount(DiscoutAmount);
        //Value[2] := POSFunctions.FormatAmount(-Transaction."Discount Amount");
        Value[1] := 'Descuento';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        IncExpAccount.SETRANGE(IncExpAccount."Store No.", Globals.StoreNo);
        IF IncExpAccount.FIND('-') THEN BEGIN
            IncExpEntry.SETCURRENTKEY("Statement Code", "Z-Report ID", "No.");
            IncExpEntry.SETRANGE("Statement Code", SCode);
            IncExpEntry.SETRANGE("Z-Report ID", '');
            IF IncExpEntry.FIND('-') THEN BEGIN
                PrintUL.PrintSeperator(2);
                DSTR1 := '#C######################################';
                Value[1] := 'FONDOS AJENOS';
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                DSTR1 := '#L#############     #R##################';
                Value[1] := 'DESCRIPCIÓN';
                Value[2] := 'MONTO';
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                DSTR1 := '#L########################## #R#########';
                REPEAT
                    IncExpEntry.SETRANGE("No.", IncExpAccount."No.");
                    IF IncExpEntry.FIND('-') THEN BEGIN
                        Value[1] := IncExpAccount.Description;
                        IncExpEntry.CALCSUMS(Amount);
                        Value[2] := POSFunctions.FormatAmount(IncExpEntry.Amount);
                        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END;
                UNTIL IncExpAccount.NEXT = 0;
            END;
        END;

        PrintUL.PrintSeperator(2);

        //Transaction counting
        IF PaymTrans3.FIND('-') THEN
            REPEAT
                IF NOT PaymTemp.GET(PaymTrans3."Store No.", PaymTrans3."POS Terminal No.", PaymTrans3."Transaction No.") THEN BEGIN
                    Transaction2.GET(PaymTrans3."Store No.", PaymTrans3."POS Terminal No.", PaymTrans3."Transaction No.");
                    IF Transaction2."Transaction Type" = Transaction2."Transaction Type"::Sales THEN
                        RecCount := RecCount + 1;
                    PaymTemp."Store No." := PaymTrans3."Store No.";
                    PaymTemp."POS Terminal No." := PaymTrans3."POS Terminal No.";
                    PaymTemp."Transaction No." := PaymTrans3."Transaction No.";
                    PaymTemp.INSERT;
                END;
            UNTIL PaymTrans3.NEXT = 0;
        Value[1] := 'No. de transacciones:';
        Value[2] := FORMAT(Transaction.COUNT, 0, '<Integer>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        Value[1] := 'Articulos vendidos:';
        Value[2] := FORMAT(Transaction."No. of Items", 0, '<Integer>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        Transaction.SETRANGE(Transaction."Sale Is Return Sale", TRUE);
        Value[1] := 'No. de devoluciones:';
        Value[2] := FORMAT(Transaction.COUNT, 0, '<Integer>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        Transaction.SETRANGE(Transaction."Sale Is Return Sale");

        SuspTrans.SETRANGE("Store No.", Store."No.");
        SuspTrans.SETRANGE("Entry Status", SuspTrans."Entry Status"::Suspended);
        NoSuspended := SuspTrans.COUNT;
        Value[1] := 'No. de suspenciones:';
        Value[2] := FORMAT(NoSuspended, 0, '<Integer>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        SuspTrans.SETRANGE("Store No.");

        IF (NoSuspended > 0) THEN BEGIN
            IF Terminal."Print Suspend with Prepayment" THEN BEGIN
                NoSuspPrepayment := 0;
                SuspPrepayment := 0;

                SuspTransLine.RESET;
                SuspTransLine.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
                SuspTransLine.SETRANGE("Entry Type", SuspTransLine."Entry Type"::IncomeExpense);
                IF SuspTransLine.FIND('-') THEN BEGIN
                    REPEAT
                        IF (SuspTransLine."POS Terminal No." = '0') THEN BEGIN
                            NoSuspPrepayment := NoSuspPrepayment + 1;
                            SuspPrepayment := SuspPrepayment + SuspTransLine.Amount;
                        END;
                    UNTIL SuspTransLine.NEXT = 0;
                END;
                SuspPrepayment := ABS(SuspPrepayment);
                IF (NoSuspPrepayment > 0) THEN BEGIN
                END;
                IF (SuspPrepayment > 0) THEN BEGIN
                END;
            END;
        END;

        Transaction.SETRANGE("Entry Status", Transaction."Entry Status"::Voided);
        Value[1] := 'No. de anulaciones:';
        Value[2] := FORMAT(Transaction.COUNT, 0, '<Integer>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        IF gNoSuspPOSTransactionsVoided <> 0 THEN BEGIN
            Value[1] := '  ' + Text230;
            Value[2] := FORMAT(gNoSuspPOSTransactionsVoided, 0, '<Integer>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
        END;

        Transaction.SETRANGE("Entry Status", Transaction."Entry Status"::Training);
        Transaction.SETRANGE("Entry Status");

        Transaction.SETFILTER("Transaction Type", '%1|%2',
        Transaction."Transaction Type"::Sales, Transaction."Transaction Type"::"Open Drawer");
        Transaction.SETRANGE("Open Drawer", TRUE);
        Transaction.SETRANGE("Open Drawer");

        Transaction.SETRANGE("Transaction Type", Transaction."Transaction Type"::Logon);
        Transaction.SETRANGE("Transaction Type");

        IF Transaction."No. of Covers" <> 0 THEN BEGIN
            Value[1] := Text235;
            Value[2] := FORMAT(Transaction."No. of Covers", 0, '<Integer>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

            Transaction.SETFILTER("Split Number", '<>%1', 0);
            NoSplitTrans := Transaction.COUNT;
            Value[1] := Text236;
            Value[2] := FORMAT(NoSplitTrans, 0, '<Integer>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
            Transaction.SETRANGE("Split Number");

            NoTables := RecCount - NoSplitTrans;

            Value[1] := Text237;
            Value[2] := FORMAT(Transaction."No. of Covers" / NoTables, 0, '<Integer>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

            Value[1] := Text238;
            Value[2] := FORMAT(RecCount / NoTables, 0, '<Integer>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
        END;

        IF WHBatchQueue.COUNT > 0 THEN BEGIN
            Value[1] := lText004;
            Value[2] := FORMAT(WHBatchQueue.COUNT, 0, '<Integer>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
        END;

        IF GenPosFunc."TS Send Transactions" AND (GenPosFunc."Send Transaction" <> '') THEN BEGIN
            TransServerWorkTable.RESET;
            TransServerWorkTable.SETRANGE(Table, DATABASE::"LSC Transaction Header");
            TransServerWorkTable.SETRANGE("Store No.", Globals.StoreNo);
            TransServerWorkTable.SETRANGE("POS Terminal No.", Globals.TerminalNo);
            TransNotSent := TransServerWorkTable.COUNT;
            IF TransNotSent > 0 THEN BEGIN
                PrintUL.PrintSeperator(2);
                CLEAR(Value);
                DSTR1 := '#L######################################';
                Value[1] := Text153;
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                Value[1] := STRSUBSTNO(Text161, TransNotSent);
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                PrintUL.PrintSeperator(2);
            END;
        END;
        //Mark every entry included in the report with Z or Y report code.
        IF Terminal."Statement Method" = Terminal."Statement Method"::"POS Terminal" THEN//28981
            Terminal.MODIFY
        ELSE BEGIN
            Staff.MODIFY;
        END;

        SaveRolloAuditor(TODAY, ZReportID, Terminal."No.");

        Terminal."Last Z-Report" := INCSTR(Terminal."Last Z-Report");
        Terminal.MODIFY;

        Commit();
        IF NOT PrintUL.ClosePrinter(2) THEN //Error .Run
            EXIT(FALSE);
        IF Transaction."Entry Status" = Transaction."Entry Status"::Training THEN
            EXIT(TRUE);

        EXIT(TRUE);
    end;

    procedure ModifyHeaderIDZreport(ZReportID: Code[10]; terminal: Code[10])
    var
        Header: Record "LSC Transaction Header";
    begin
        Header.reset;
        Header.SetRange(Header."Store No.", POSSESSION.StoreNo());
        Header.SetRange(Header."POS Terminal No.", POSSESSION.TerminalNo());
        Header.SetRange(Header."Z-Report ID", '');
        if Header.FindSet() then BEGIN
            repeat
                Header."Z-Report ID" := ZReportID;
                Header.Modify(true);
            UNTIL Header.NEXT = 0;
        END;
    end;
    //////////////////////////////////////////XXXXXX///////////////////////////////////////////////////////
    procedure PrintXZReportSV_X(): Boolean
    var
        PaymentFilt: Record "LSC Trans. Payment Entry";
        AmountTotal: Decimal;
        DiscoutAmount: Decimal;
    begin
        Nicopu := 0;
        //longitud campos texto autorizacion 20a30
        IF NOT Staff.GET(Globals.StaffID) THEN
            EXIT(TRUE);
        IF NOT Terminal.GET(Globals.TerminalNo) THEN
            EXIT(TRUE);
        IF NOT PrintUL.OpenReceiptPrinter(2, 'TENDER', 'ZXREPORT', 0, '') THEN
            EXIT(FALSE);

        Store.GET(Globals.StoreNo());


        IF FiscalON THEN BEGIN
            PrintUL.FiscalPrintXZReport(RunParameter::X);
            IF OnlyFiscal THEN
                EXIT(PrintUL.ClosePrinter(2));
        END;

        IF NOT Terminal."Terminal Statement" THEN
            Terminal."Statement Method" := Store."Statement Method";

        SCode := POSFunctions.GetStatementCode;

        Transaction.Date := TODAY;
        Transaction.Time := TIME;
        PrintUL.PrintSeperator(2);

        //X or Z Report..
        DSTR1 := '#C############################';
        Value[1] := Text107;
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

        IF GenPosFunc."TS Floating Cashier" AND
           (Terminal."Statement Method" = Terminal."Statement Method"::Staff) AND
           (Globals.GetValue('TS_ERROR') <> '') THEN BEGIN
        END;
        PrintUL.PrintSeperator(2);
        //información general
        DSTR1 := '#L######################################';
        Value[1] := 'Fecha: ' + FORMAT(TODAY, 0, '<Day,2>/<Month,2>/<Year4>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        DSTR1 := '#L######################################';
        Value[1] := 'Hora: ' + FORMAT(TIME(), 0, '<Hours12>:<Minutes,2> <AM/PM>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Nombre de la empresa...
        rCompanyInfo.GET();
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := rCompanyInfo.Name;
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Codigo Tipo Contribuyente y  No. Reg. Contribuyente de la empresa...
        rCompanyInfo.GET();
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := TextNRC + ':' + rCompanyInfo."FSN NRC";
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir NIT de la empresa...
        rCompanyInfo.GET();
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := TextRNC + ':' + rCompanyInfo."Federal ID No.";
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Giro de la empresa...
        rCompanyInfo.GET();
        DSTR1 := COPYSTR('#C#######################################', 1);
        Value[1] := TextGIRO + '::' + COPYSTR(rCompanyInfo."FSN NRC Description", 1, 26);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        DSTR1 := COPYSTR('#C#######################################', 1);
        Value[1] := COPYSTR(rCompanyInfo."FSN NRC Description", 26, 39);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Nombre de la tienda.
        DSTR1 := COPYSTR('#L######################################', 1);
        Value[1] := Store.Name;
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir 1era. direccion de la tienda.
        DSTR1 := COPYSTR('#L######################################', 1);
        Value[1] := Store.Address;
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir 2da. direccion de la tienda.
        IF Store."Address 2" <> '' THEN BEGIN
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := Store."Address 2";
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;

        //Imprimir el No. de la Caja..
        DSTR1 := COPYSTR('#L################## #R#################', 1);
        Value[1] := TextCodTienda + ' ' + Store."No.";
        Value[2] := TextCaja + ' ' + Terminal."No.";
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        PrintUL.PrintSeperator(2);
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := 'Corte X No.: ' + INCSTR(Terminal."FSN Last X-Report");
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
        PrintUL.PrintSeperator(2);
        //  Totals for LCY
        IF LocalTotal <> 0 THEN BEGIN
            PrintUL.PrintSeperator(2);
            DSTR1 := '#L########              #R##############';
            Value[1] := Text005 + ':';
            Value[2] := POSFunctions.FormatAmount(LocalTotal);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
        END;

        NicopuPaymentEntry.RESET;
        NicopuPaymentEntry.SetRange(NicopuPaymentEntry."POS Terminal No.", POSSESSION.TerminalNo());
        NicopuPaymentEntry.SetRange(NicopuPaymentEntry."Z-Report ID", '');
        NicopuPaymentEntry.SetRange(NicopuPaymentEntry."Tender Type", '11');
        NicopuPaymentEntry.SetRange(NicopuPaymentEntry."Safe type", NicopuPaymentEntry."Safe type"::" ");
        if NicopuPaymentEntry.Find('-') then begin
            repeat
                NicopuSUM := NicopuSUM + NicopuPaymentEntry."Amount Tendered";
                Nicopu := Nicopu + NicopuPaymentEntry."Amount in Currency";
            until NicopuPaymentEntry.Next() = 0;
        end;

        PrintUL.PrintSeperator(2);
        DSTR1 := '#C######################################';
        Value[1] := 'NICOPUNTOS: ' + Format(Nicopu) + '  ' + Format(NicopuSUM);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
        //PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), true, false, true, false));
        PrintUL.PrintSeperator(2);


        //  Totals for FCY
        PrintUL.PrintLine(2, '');
        TenderType.SETRANGE("Foreign Currency", TRUE);

        TotalLCYInCurrency := 0;
        //PrintXZLines();28981
        IF TotalLCYInCurrency <> 0 THEN BEGIN
            PrintUL.PrintSeperator(2);
            DSTR1 := '#L##################### #R##############';
            Value[1] := Text300;
            Value[2] := POSFunctions.FormatAmount(TotalLCYInCurrency);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
            PrintUL.PrintLine(2, '');
            PrintUL.PrintSeperator(2);
        END;
        //  Tender Declaration
        Transaction."Transaction No." := 0;
        TendDeclEntry.SETCURRENTKEY("Statement Code", "Z-Report ID", "Tender Type", "Currency Code", "Card No.");
        TendDeclEntry.SETRANGE("Statement Code", SCode);
        TendDeclEntry.SETRANGE("Z-Report ID", '');

        IF Store."Tend. Decl. Calculation" = Store."Tend. Decl. Calculation"::Sum THEN BEGIN
            BufferTendDeclEntry;
            IF TendDeclEntry.FIND('-') THEN
                Transaction."Transaction No." := TendDeclEntry."Transaction No.";
        END ELSE BEGIN
            IF TendDeclEntry.FIND('-') THEN
                REPEAT
                    IF TendDeclEntry."Transaction No." > Transaction."Transaction No." THEN
                        Transaction.GET(TendDeclEntry."Store No.", TendDeclEntry."POS Terminal No.", TendDeclEntry."Transaction No.")
                UNTIL TendDeclEntry.NEXT = 0;
        END;

        IF Transaction."Transaction No." <> 0 THEN BEGIN
            CLEAR(TendDeclEntry);
            LocalTotal := 0;
            IF Store."Tend. Decl. Calculation" = Store."Tend. Decl. Calculation"::Last THEN BEGIN
                TendDeclEntry.SETCURRENTKEY("Store No.", "POS Terminal No.", "Transaction No.");
                TendDeclEntry.SETRANGE("Store No.", Transaction."Store No.");
                TendDeclEntry.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
                TendDeclEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
                BufferTendDeclEntry;
            END;
            TempTendDeclEntry.SETFILTER("Currency Code", '=%1', '');
            Transaction."Gross Amount" := -LocalTotal;
            TempTendDeclEntry.SETFILTER("Currency Code", '<>%1', '');
        END;

        //contenido cortes
        vVentasGravadasTotales := 0;
        vImpuestoIVATotales := 0;
        vTotalGravadoTotales := 0;
        vVentasExentasTotales := 0;
        vVentasNoSujetasTotales := 0;
        vVentasTotalesTotales := 0;
        vIVAPercibidoTotales := 0;
        vIVAPercibidoDevTotales := 0;
        vIVARetenidoTotales := 0;
        vCESCTotales := 0;

        //ENCABEZADO PARA EL TIPO DE COMPROBANTE
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := '1- Ticket';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

        Transaction2.RESET;
        Transaction2.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
        Transaction2.SETRANGE(Transaction2."POS Terminal No.", Terminal."No.");
        Transaction2.SETRANGE("Statement Code", SCode);
        Transaction2.SETRANGE("Z-Report ID", '');
        Transaction2.SETRANGE("Transaction Type", Transaction2."Transaction Type"::Sales);
        Transaction2.SETFILTER("Entry Status", '%1|%2|%3', Transaction2."Entry Status"::" ", Transaction2."Entry Status"::Posted, Transaction2."Entry Status"::Voided);
        Transaction2.SETRANGE("FSN No. Serie NCF", Terminal."FSN No. Serie NCF Ticket");
        IF Transaction2.FINDFIRST THEN BEGIN
            Terminal.RESET;
            Terminal.GET(POSSESSION.TerminalNo());
            rNoSeries.RESET;
            IF rNoSeries.GET(Terminal."FSN No. Serie NCF Ticket") THEN BEGIN
                rNoSeriesLn.RESET;
                rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
                IF rNoSeriesLn.FINDFIRST THEN BEGIN
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := 'Autorizacion: ' + UPPERCASE(rNoSeriesLn."FSN Autorization");
                    PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    //Imprimir el rango de ticket..
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := 'Del ' + rNoSeriesLn."Starting No.";

                    PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    DSTR1 := COPYSTR('#L######################################', 1);

                    Value[1] := 'al  ' + rNoSeriesLn."Ending No.";
                    PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
            END;

            FirstTicket := Transaction2."FSN NCF";

            REPEAT
                CLEAR(Venta);
                CLEAR(Iva);
                CLEAR(vTotal);
                rSalesEntry.SETRANGE("Store No.", Transaction2."Store No.");
                rSalesEntry.SETRANGE("POS Terminal No.", Transaction2."POS Terminal No.");
                rSalesEntry.SETRANGE("Transaction No.", Transaction2."Transaction No.");
                IF rSalesEntry.FIND('-') THEN
                    REPEAT
                        IF rSalesEntry."FSN Remission No." <> '' THEN BEGIN
                            Venta += -(rSalesEntry."Net Amount");
                            Iva += -(rSalesEntry."VAT Amount");
                            vTotal += -(rSalesEntry."Net Amount") + -(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += -(rSalesEntry."Net Amount");
                                    TotalIva += -(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += -(rSalesEntry."Net Amount");
                                    TotalIvaNcr += -(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += -(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += -(rSalesEntry."Net Amount");
                                END;
                            END;
                        END ELSE BEGIN
                            Venta += ABS(rSalesEntry."Net Amount");
                            Iva += ABS(rSalesEntry."VAT Amount");
                            vTotal += ABS(rSalesEntry."Net Amount") + ABS(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += ABS(rSalesEntry."Net Amount");
                                    TotalIva += ABS(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += ABS(rSalesEntry."Net Amount");
                                    TotalIvaNcr += ABS(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += ABS(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += ABS(rSalesEntry."Net Amount");
                                END;
                            END;
                        END;
                    UNTIL rSalesEntry.NEXT = 0;

                LastTicket := Transaction2."FSN NCF";

            UNTIL Transaction2.NEXT = 0;
        END;
        IF (FirstTicket <> '') OR (LastTicket <> '') THEN BEGIN
            //Del No.
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := 'Del No.: ' + FirstTicket;
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            //Al No.
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := 'Al No.: ' + LastTicket;
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        VentasG := VentasG - TotalVentNcr;

        //VENTAS GRAVADAS...
        DSTR1 := COPYSTR('#L##############         #R#############', 1);
        Value[1] := 'Ventas Gravadas:';
        Value[2] := '$' + FORMAT(VentasG, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        TotalIva := TotalIva - TotalIvaNcr;

        //IMPUESTO IVA...
        DSTR1 := COPYSTR('#L###########            #R#############', 1);
        Value[1] := 'Impuesto IVA:';

        Value[2] := '$' + FORMAT(TotalIva - vCESC, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //IMPUESTO CESC...
        DSTR1 := COPYSTR('#L############           #R#############', 1);
        Value[1] := 'Impuesto CESC:';
        Value[2] := '$' + FORMAT(vCESC, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Total Gravado...
        DSTR1 := COPYSTR('#L############           #R#############', 1);
        Value[1] := 'Total Gravado:';
        Value[2] := '$' + FORMAT(VentasG + TotalIva, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS EXENTAS...
        DSTR1 := COPYSTR('#L#############          #R#############', 1);
        Value[1] := 'Ventas Exentas:';
        Value[2] := '$' + FORMAT((VentasE - VentasEDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS NO SUJETAS...
        DSTR1 := COPYSTR('#L################       #R#############', 1);
        Value[1] := 'Ventas No Sujetas:';
        Value[2] := '$' + FORMAT((VentasNoSu - VentasNoSuDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS TOTALES
        DSTR1 := COPYSTR('#L#############          #R#############', 1);
        Value[1] := 'Ventas Totales:';
        Value[2] := '$' + FORMAT((VentasG + TotalIva + VentasE + VentasNoSu) - (VentasEDev + VentasNoSuDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        vVentasGravadasTotales := vVentasGravadasTotales + VentasG;
        vImpuestoIVATotales := vImpuestoIVATotales + TotalIva - vCESC;
        vCESCTotales := vCESCTotales + vCESC;
        vTotalGravadoTotales := vTotalGravadoTotales + (VentasG + TotalIva);
        vVentasExentasTotales := vVentasExentasTotales + (VentasE - VentasEDev);
        vVentasNoSujetasTotales := vVentasNoSujetasTotales + (VentasNoSu - VentasNoSuDev);
        vVentasTotalesTotales := vVentasTotalesTotales + ((VentasG + TotalIva + VentasE + VentasNoSu) - (VentasEDev + VentasNoSuDev));

        //LIMPIO LAS VARIABLES QUE MUESTRAN LOS TOTALES DE LAS VENTAS POR TIPO DE COMPROBANTES.
        CLEAR(FirstTicket);
        CLEAR(LastTicket);
        CLEAR(Venta);
        CLEAR(Iva);
        CLEAR(vTotal);
        CLEAR(VentasG);
        CLEAR(TotalIva);
        CLEAR(TotalVentNcr);
        CLEAR(TotalIvaNcr);
        CLEAR(VentasE);
        CLEAR(VentasNoSu);
        CLEAR(VentasEDev);
        CLEAR(VentasNoSuDev);
        CLEAR(vCESC);

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //ENCABEZADO PARA EL TIPO DE COMPROBANTE
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := '2- Comprobante de Crédito Fiscal';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

        //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
        //se agrego rango de facturas
        //BUSCO PRIMERO LOS NCF PARA CREDITO FISCALES
        Terminal.RESET;
        Terminal.GET(POSSESSION.TerminalNo());
        Transaction2.RESET;
        Transaction2.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
        Transaction2.SETRANGE(Transaction2."POS Terminal No.", Terminal."No.");
        Transaction2.SETRANGE("Statement Code", SCode);
        Transaction2.SETRANGE("Z-Report ID", '');
        Transaction2.SETRANGE("Transaction Type", Transaction2."Transaction Type"::Sales);
        Transaction2.SETFILTER("Entry Status", '%1|%2|%3', Transaction2."Entry Status"::" ", Transaction2."Entry Status"::Posted, Transaction2."Entry Status"::Voided);
        Transaction2.SETRANGE("FSN No. Serie NCF", Terminal."FSN No. Serie Credito Fiscal");
        IF Transaction2.FINDFIRST THEN BEGIN
            rNoSeries.RESET;
            IF rNoSeries.GET(Terminal."FSN No. Serie Credito Fiscal") THEN BEGIN
                rNoSeriesLn.RESET;
                rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
                IF rNoSeriesLn.FINDFIRST THEN BEGIN
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := 'Autorizacion: ' + UPPERCASE(rNoSeriesLn."FSN Autorization");
                    PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := 'Del ' + rNoSeriesLn."Starting No.";
                    PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := 'al  ' + rNoSeriesLn."Ending No.";
                    PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
            END;
            //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
            //se agrego rango de facturas
            FirstFactCrf := Transaction2."FSN NCF";
            vFirstFechaCref := Transaction2.Date;
            //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda

            REPEAT
                CLEAR(Venta);
                CLEAR(Iva);
                CLEAR(vTotal);
                rSalesEntry.SETRANGE("Store No.", Transaction2."Store No.");
                rSalesEntry.SETRANGE("POS Terminal No.", Transaction2."POS Terminal No.");
                rSalesEntry.SETRANGE("Transaction No.", Transaction2."Transaction No.");
                IF rSalesEntry.FIND('-') THEN
                    REPEAT
                        IF rSalesEntry."FSN Remission No." <> '' THEN BEGIN
                            Venta += -(rSalesEntry."Net Amount");
                            Iva += -(rSalesEntry."VAT Amount");
                            vTotal += -(rSalesEntry."Net Amount") + -(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += -(rSalesEntry."Net Amount");
                                    TotalIva += -(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += -(rSalesEntry."Net Amount");
                                    TotalIvaNcr += -(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += -(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += -(rSalesEntry."Net Amount");
                                END;
                            END;
                        END ELSE BEGIN
                            Venta += ABS(rSalesEntry."Net Amount");
                            Iva += ABS(rSalesEntry."VAT Amount");
                            vTotal += ABS(rSalesEntry."Net Amount") + ABS(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += ABS(rSalesEntry."Net Amount");
                                    TotalIva += ABS(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += ABS(rSalesEntry."Net Amount");
                                    TotalIvaNcr += ABS(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += ABS(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += ABS(rSalesEntry."Net Amount");
                                END;
                            END;
                        END;
                    UNTIL rSalesEntry.NEXT = 0;
                //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                //se agrego rango de facturas
                LastFactCrf := Transaction2."FSN NCF";
                vLastFechaCref := Transaction2.Date;
                //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                IF NOT Transaction2."Sale Is Return Sale" THEN
                    Percepcion += ABS(Transaction2."FSN Perception Amount")
                ELSE
                    PercepcionDev += -(Transaction2."FSN Perception Amount");
            UNTIL Transaction2.NEXT = 0;
        END;

        //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
        //se agrego rango de facturas
        IF (FirstFactCrf <> '') OR (LastFactCrf <> '') THEN BEGIN
            rNoSeriesLn.RESET;
            rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
            IF rNoSeriesLn.FINDFIRST THEN
                REPEAT
                    IF ((rNoSeriesLn."Starting No." <= FirstFactCrf) AND (rNoSeriesLn."Ending No." >= FirstFactCrf)) AND
                    ((rNoSeriesLn."Starting Date" <= vFirstFechaCref) AND (rNoSeriesLn."Last Date Used" >= vFirstFechaCref)) THEN
                        vFirstFactCredAut := UPPERCASE(rNoSeriesLn.Series);
                    IF ((rNoSeriesLn."Starting No." <= LastFactCrf) AND (rNoSeriesLn."Ending No." >= LastFactCrf)) AND
                    ((rNoSeriesLn."Starting Date" <= vLastFechaCref) AND (rNoSeriesLn."Last Date Used" >= vLastFechaCref)) THEN
                        vLastFactCredAut := UPPERCASE(rNoSeriesLn.Series);
                UNTIL rNoSeriesLn.NEXT = 0;

            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := 'Del No.: ' + vFirstFactCredAut + ' ' + FirstFactCrf;
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := 'Al No.: ' + vLastFactCredAut + ' ' + LastFactCrf;
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;

        //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        VentasG := VentasG - TotalVentNcr;

        //VENTAS GRAVADAS...
        DSTR1 := COPYSTR('#L##############    #R##################', 1);
        Value[1] := 'Ventas Gravadas:';
        Value[2] := '$' + FORMAT(VentasG, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        TotalIva := TotalIva - TotalIvaNcr;

        //IMPUESTO IVA...
        DSTR1 := COPYSTR('#L###########       #R##################', 1);
        Value[1] := 'Impuesto IVA:';
        Value[2] := '$' + FORMAT(TotalIva - vCESC, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //IMPUESTO CESC...
        DSTR1 := COPYSTR('#L############           #R#############', 1);
        Value[1] := 'Impuesto CESC:';
        Value[2] := '$' + FORMAT(vCESC, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Total Gravado...
        DSTR1 := COPYSTR('#L############      #R##################', 1);
        Value[1] := 'Total Gravado:';
        Value[2] := '$' + FORMAT(VentasG + TotalIva, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        CLEAR(Percibido);
        //PERCEPCION...
        DSTR1 := COPYSTR('#L################# #R##################', 1);
        Value[1] := '(+) IVA Percibido:';
        Value[2] := '$' + FORMAT((Percepcion), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS EXENTAS...
        DSTR1 := COPYSTR('#L#############     #R##################', 1);
        Value[1] := 'Ventas Exentas:';
        Value[2] := '$' + FORMAT((VentasE), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS NO SUJETAS...
        DSTR1 := COPYSTR('#L################  #R##################', 1);
        Value[1] := 'Ventas No Sujetas:';
        Value[2] := '$' + FORMAT((VentasNoSu), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS TOTALES
        DSTR1 := COPYSTR('#L#############     #R##################', 1);
        Value[1] := 'Ventas Totales:';
        Value[2] := '$' + FORMAT((VentasG + TotalIva + VentasE + VentasNoSu + Percepcion), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        vVentasGravadasTotales := vVentasGravadasTotales + VentasG;
        vImpuestoIVATotales := vImpuestoIVATotales + TotalIva - vCESC;
        vCESCTotales := vCESCTotales + vCESC;
        vTotalGravadoTotales := vTotalGravadoTotales + (VentasG + TotalIva);
        vVentasExentasTotales := vVentasExentasTotales + (VentasE - VentasEDev);
        vVentasNoSujetasTotales := vVentasNoSujetasTotales + (VentasNoSu - VentasNoSuDev);
        vVentasTotalesTotales := vVentasTotalesTotales + ((VentasG + TotalIva + VentasE + VentasNoSu + (Percepcion - PercepcionDev)) - (VentasEDev + VentasNoSuDev));
        vIVAPercibidoTotales := vIVAPercibidoTotales + (Percepcion);

        //LIMPIO LAS VARIABLES QUE MUESTRAN LOS TOTALES DE LAS VENTAS POR TIPO DE COMPROBANTES.
        CLEAR(Venta);
        CLEAR(Iva);
        CLEAR(vTotal);
        CLEAR(VentasG);
        CLEAR(TotalIva);
        CLEAR(TotalVentNcr);
        CLEAR(TotalIvaNcr);
        CLEAR(VentasE);
        CLEAR(VentasNoSu);
        CLEAR(VentasEDev);
        CLEAR(VentasNoSuDev);
        CLEAR(Retencion);
        CLEAR(Percepcion);
        CLEAR(vCESC);

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //ENCABEZADO PARA EL TIPO DE COMPROBANTE
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := '3- Nota de Crédito';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

        //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
        //se agrego rango de facturas
        Transaction2.RESET;
        Transaction2.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
        Transaction2.SETRANGE(Transaction2."POS Terminal No.", Terminal."No.");
        Transaction2.SETRANGE("Statement Code", SCode);
        Transaction2.SETRANGE("Z-Report ID", '');
        Transaction2.SETRANGE("Transaction Type", Transaction2."Transaction Type"::Sales);

        Transaction2.SETFILTER("Entry Status", '%1|%2|%3', Transaction2."Entry Status"::" ", Transaction2."Entry Status"::Posted, Transaction2."Entry Status"::Voided);
        Transaction2.SETRANGE("FSN No. Serie NCF", Terminal."FSN No. Serie Nota de Credito");
        IF Transaction2.FINDFIRST THEN BEGIN
            rNoSeries.RESET;
            IF rNoSeries.GET(Terminal."FSN No. Serie Nota de Credito") THEN BEGIN
                rNoSeriesLn.RESET;
                rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
                IF rNoSeriesLn.FINDFIRST THEN BEGIN
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := 'Autorizacion: ' + UPPERCASE(rNoSeriesLn."FSN Autorization");
                    PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := 'Del ' + rNoSeriesLn."Starting No.";
                    PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := 'al  ' + rNoSeriesLn."Ending No.";
                    PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
            END;
            //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
            //se agrego rango de facturas
            FirstFactCrfDev := Transaction2."FSN NCF";
            vFirstFechaNocre := Transaction2.Date;
            //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda

            REPEAT
                CLEAR(Venta);
                CLEAR(Iva);
                CLEAR(vTotal);
                rSalesEntry.SETRANGE("Store No.", Transaction2."Store No.");
                rSalesEntry.SETRANGE("POS Terminal No.", Transaction2."POS Terminal No.");
                rSalesEntry.SETRANGE("Transaction No.", Transaction2."Transaction No.");
                IF rSalesEntry.FIND('-') THEN
                    REPEAT
                        IF rSalesEntry."FSN Remission No." <> '' THEN BEGIN
                            Venta += -(rSalesEntry."Net Amount");
                            Iva += -(rSalesEntry."VAT Amount");
                            vTotal += -(rSalesEntry."Net Amount") + -(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += -(rSalesEntry."Net Amount");
                                    TotalIva += -(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += -(rSalesEntry."Net Amount");
                                    TotalIvaNcr += -(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += -(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += -(rSalesEntry."Net Amount");
                                END;
                            END;
                        END ELSE BEGIN
                            Venta += ABS(rSalesEntry."Net Amount");
                            Iva += ABS(rSalesEntry."VAT Amount");
                            vTotal += ABS(rSalesEntry."Net Amount") + ABS(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += ABS(rSalesEntry."Net Amount");
                                    TotalIva += ABS(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += ABS(rSalesEntry."Net Amount");
                                    TotalIvaNcr += ABS(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += ABS(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += ABS(rSalesEntry."Net Amount");
                                END;
                            END;
                        END;
                    UNTIL rSalesEntry.NEXT = 0;
                //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                //se agrego rango de facturas
                LastFactCrfDev := Transaction2."FSN NCF";
                vLastFechaNocre := Transaction2.Date;
                //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                IF NOT Transaction2."Sale Is Return Sale" THEN
                    Percepcion += ABS(Transaction2."FSN Perception Amount")
                ELSE
                    PercepcionDev += -(Transaction2."FSN Perception Amount");
            UNTIL Transaction2.NEXT = 0;
        END;

        //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
        //se agrego rango de facturas
        IF (FirstFactCrfDev <> '') OR (LastFactCrfDev <> '') THEN BEGIN
            rNoSeriesLn.RESET;
            rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
            IF rNoSeriesLn.FINDFIRST THEN
                REPEAT
                    IF ((rNoSeriesLn."Starting No." <= FirstFactCrfDev) AND (rNoSeriesLn."Ending No." >= FirstFactCrfDev)) AND
                    ((rNoSeriesLn."Starting Date" <= vFirstFechaNocre) AND (rNoSeriesLn."Last Date Used" >= vFirstFechaNocre)) THEN
                        vFirstFactCredAut := UPPERCASE(rNoSeriesLn.Series);
                    IF ((rNoSeriesLn."Starting No." <= LastFactCrfDev) AND (rNoSeriesLn."Ending No." >= LastFactCrfDev)) AND
                    ((rNoSeriesLn."Starting Date" <= vLastFechaNocre) AND (rNoSeriesLn."Last Date Used" >= vLastFechaNocre)) THEN
                        vLastFactCredAut := UPPERCASE(rNoSeriesLn.Series);
                UNTIL rNoSeriesLn.NEXT = 0;
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := 'Del No.: ' + vFirstFactCredAut + ' ' + FirstFactCrfDev;
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := 'Al No.: ' + vLastFactCredAut + ' ' + LastFactCrfDev;
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;
        //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        VentasG := VentasG - TotalVentNcr;

        //VENTAS GRAVADAS...
        DSTR1 := COPYSTR('#L##############    #R##################', 1);
        Value[1] := 'Ventas Gravadas:';
        Value[2] := '$' + FORMAT(VentasG, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        TotalIva := TotalIva - TotalIvaNcr;

        //IMPUESTO IVA...
        DSTR1 := COPYSTR('#L###########       #R##################', 1);
        Value[1] := 'Impuesto IVA:';
        Value[2] := '$' + FORMAT(TotalIva, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Total Gravado...
        DSTR1 := COPYSTR('#L############      #R##################', 1);
        Value[1] := 'Total Gravado:';
        Value[2] := '$' + FORMAT(VentasG + TotalIva, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        CLEAR(Percibido);
        //PERCEPCION...
        DSTR1 := COPYSTR('#L################# #R##################', 1);
        Value[1] := '(+) IVA Percibido:';
        Value[2] := '$' + FORMAT((-PercepcionDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS EXENTAS...
        DSTR1 := COPYSTR('#L#############     #R##################', 1);
        Value[1] := 'Ventas Exentas:';
        Value[2] := '$' + FORMAT((VentasE - VentasEDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS NO SUJETAS...
        DSTR1 := COPYSTR('#L################  #R##################', 1);
        Value[1] := 'Ventas No Sujetas:';
        Value[2] := '$' + FORMAT((VentasNoSu - VentasNoSuDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS TOTALES
        DSTR1 := COPYSTR('#L#############     #R##################', 1);
        Value[1] := 'Ventas Totales:';
        Value[2] := '$' + FORMAT((VentasG + TotalIva + VentasE + VentasNoSu + (PercepcionDev + Percepcion)) - (VentasEDev + VentasNoSuDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        vVentasGravadasTotales := vVentasGravadasTotales + VentasG;
        vImpuestoIVATotales := vImpuestoIVATotales + TotalIva;
        vTotalGravadoTotales := vTotalGravadoTotales + (VentasG + TotalIva);
        vVentasExentasTotales := vVentasExentasTotales + (VentasE - VentasEDev);
        vVentasTotalesTotales := vVentasTotalesTotales + ((VentasG + TotalIva + VentasE + VentasNoSu + (PercepcionDev + Percepcion)) - (VentasEDev + VentasNoSuDev));
        vIVAPercibidoDevTotales := vIVAPercibidoDevTotales + (-PercepcionDev);

        //LIMPIO LAS VARIABLES QUE MUESTRAN LOS TOTALES DE LAS VENTAS POR TIPO DE COMPROBANTES.
        CLEAR(Venta);
        CLEAR(Iva);
        CLEAR(vTotal);
        CLEAR(VentasG);
        CLEAR(TotalIva);
        CLEAR(TotalVentNcr);
        CLEAR(TotalIvaNcr);
        CLEAR(VentasE);
        CLEAR(VentasNoSu);
        CLEAR(VentasEDev);
        CLEAR(VentasNoSuDev);
        CLEAR(Retencion);

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Solo aparece el valor total de documentos de devolución en detalle de factura de consumidor final
        //ENCABEZADO PARA EL TIPO DE COMPROBANTE
        //BUSCO PRIMERO LOS NCF PARA FACTURAS DE CONSUMIDORES FINALES
        Transaction2.RESET;
        Transaction2.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
        Transaction2.SETRANGE(Transaction2."POS Terminal No.", Terminal."No.");
        Transaction2.SETRANGE("Statement Code", SCode);
        Transaction2.SETRANGE("Z-Report ID", '');
        Transaction2.SETRANGE("Transaction Type", Transaction2."Transaction Type"::Sales);
        Transaction2.SETFILTER("Entry Status", '%1|%2', Transaction2."Entry Status"::" ", Transaction2."Entry Status"::Posted);
        Transaction2.SETRANGE("FSN No. Serie NCF", Terminal."FSN No. Serie Devolucion");
        IF Transaction2.FINDFIRST THEN BEGIN
            //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
            //se agrego rango de facturas
            FirstFactCfDev := Transaction2."FSN NCF";
            REPEAT
                CLEAR(Venta);
                CLEAR(Iva);
                CLEAR(vTotal);
                rSalesEntry.SETRANGE("Store No.", Transaction2."Store No.");
                rSalesEntry.SETRANGE("POS Terminal No.", Transaction2."POS Terminal No.");
                rSalesEntry.SETRANGE("Transaction No.", Transaction2."Transaction No.");
                IF rSalesEntry.FIND('-') THEN
                    REPEAT
                        IF rSalesEntry."FSN Remission No." <> '' THEN BEGIN
                            Venta += -(rSalesEntry."Net Amount");
                            Iva += -(rSalesEntry."VAT Amount");
                            vTotal += -(rSalesEntry."Net Amount") + -(rSalesEntry."VAT Amount");
                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += -(rSalesEntry."Net Amount");
                                    TotalIva += -(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += -(rSalesEntry."Net Amount");
                                    TotalIvaNcr += -(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += -(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += -(rSalesEntry."Net Amount");
                                END;
                            END;
                        END ELSE BEGIN
                            Venta += ABS(rSalesEntry."Net Amount");
                            Iva += ABS(rSalesEntry."VAT Amount");
                            vTotal += ABS(rSalesEntry."Net Amount") + ABS(rSalesEntry."VAT Amount");
                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += ABS(rSalesEntry."Net Amount");
                                    TotalIva += ABS(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += ABS(rSalesEntry."Net Amount");
                                    TotalIvaNcr += ABS(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += ABS(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += ABS(rSalesEntry."Net Amount");
                                END;
                            END;
                        END;
                    UNTIL rSalesEntry.NEXT = 0;

                //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                //se agrego rango de facturas
                LastFactCfDev := Transaction2."FSN NCF";

                IF NOT Transaction2."Sale Is Return Sale" THEN
                    Retencion += ABS(Transaction2."FSN Retention Amount")
                ELSE
                    RetencionDev += -(Transaction2."FSN Retention Amount");

            UNTIL Transaction2.NEXT = 0;
        END;

        //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
        //se agrego rango de facturas
        VentasG := VentasG - TotalVentNcr;
        TotalIva := TotalIva - TotalIvaNcr;
        //TOTAL documentos devolucion
        vTotalDocDevolucion := (VentasG + VentasE + VentasNoSu) - (VentasEDev + VentasNoSuDev);
        vTotalIvaDocDevolucion := TotalIva;

        vTotalRetencionDev := RetencionDev;
        VentasEDevDocDev := VentasEDev;
        vVentasExentasTotales := vVentasExentasTotales + (VentasE - VentasEDev);

        //LIMPIO LAS VARIABLES QUE MUESTRAN LOS TOTALES DE LAS VENTAS POR TIPO DE COMPROBANTES.
        CLEAR(Venta);
        CLEAR(Iva);
        CLEAR(vTotal);
        CLEAR(VentasG);
        CLEAR(TotalIva);
        CLEAR(TotalVentNcr);
        CLEAR(TotalIvaNcr);
        CLEAR(VentasE);
        CLEAR(VentasNoSu);
        CLEAR(VentasEDev);
        CLEAR(VentasNoSuDev);
        //ENCABEZADO PARA EL TIPO DE COMPROBANTE
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := '4- Factura De Consumidor Final';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

        //BUSCO PRIMERO LOS NCF PARA FACTURAS DE CONSUMIDORES FINALES
        Transaction2.RESET;
        Transaction2.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
        Transaction2.SETRANGE(Transaction2."POS Terminal No.", Terminal."No.");
        Transaction2.SETRANGE("Statement Code", SCode);
        Transaction2.SETRANGE("Z-Report ID", '');
        Transaction2.SETRANGE("Transaction Type", Transaction2."Transaction Type"::Sales);
        Transaction2.SETFILTER("Entry Status", '%1|%2|%3', Transaction2."Entry Status"::" ", Transaction2."Entry Status"::Posted, Transaction2."Entry Status"::Voided);
        Transaction2.SETRANGE("FSN No. Serie NCF", Terminal."FSN No. Serie NCF Cons. Final");
        IF Transaction2.FINDFIRST THEN BEGIN
            rNoSeries.RESET;
            IF rNoSeries.GET(Terminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                rNoSeriesLn.RESET;
                rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
                IF rNoSeriesLn.FINDFIRST THEN BEGIN
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := 'Autorizacion: ' + UPPERCASE(rNoSeriesLn."FSN Autorization");
                    PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := 'Del ' + rNoSeriesLn."Starting No.";
                    PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    DSTR1 := COPYSTR('#L######################################', 1);
                    Value[1] := 'al  ' + rNoSeriesLn."Ending No.";
                    PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
            END;

            //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
            //se agrego rango de facturas
            FirstFactCf := Transaction2."FSN NCF";
            vFirstFechaFac := Transaction2.Date;
            REPEAT
                CLEAR(Venta);
                CLEAR(Iva);
                CLEAR(vTotal);
                rSalesEntry.SETRANGE("Store No.", Transaction2."Store No.");
                rSalesEntry.SETRANGE("POS Terminal No.", Transaction2."POS Terminal No.");
                rSalesEntry.SETRANGE("Transaction No.", Transaction2."Transaction No.");
                IF rSalesEntry.FIND('-') THEN
                    REPEAT
                        IF rSalesEntry."FSN Remission No." <> '' THEN BEGIN
                            Venta += -(rSalesEntry."Net Amount");
                            Iva += -(rSalesEntry."VAT Amount");
                            vTotal += -(rSalesEntry."Net Amount") + -(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += -(rSalesEntry."Net Amount");
                                    TotalIva += -(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += -(rSalesEntry."Net Amount");
                                    TotalIvaNcr += -(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += -(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += -(rSalesEntry."Net Amount");
                                END;
                            END;
                        END ELSE BEGIN
                            Venta += ABS(rSalesEntry."Net Amount");
                            Iva += ABS(rSalesEntry."VAT Amount");
                            vTotal += ABS(rSalesEntry."Net Amount") + ABS(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += ABS(rSalesEntry."Net Amount");
                                    TotalIva += ABS(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += ABS(rSalesEntry."Net Amount");
                                    TotalIvaNcr += ABS(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += ABS(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += ABS(rSalesEntry."Net Amount");
                                END;
                            END;
                        END;
                    UNTIL rSalesEntry.NEXT = 0;


                //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                //se agrego rango de facturas
                LastFactCf := Transaction2."FSN NCF";
                vLastFechaFac := Transaction2.Date;
                IF NOT Transaction2."Sale Is Return Sale" THEN
                    Retencion += ABS(Transaction2."FSN Retention Amount")
                ELSE
                    RetencionDev += -(Transaction2."FSN Retention Amount");
            UNTIL Transaction2.NEXT = 0;
        END;

        //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
        //se agrego rango de facturas
        IF (FirstFactCf <> '') OR (LastFactCf <> '') THEN BEGIN
            rNoSeriesLn.RESET;
            rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
            IF rNoSeriesLn.FINDFIRST THEN
                REPEAT
                    IF ((rNoSeriesLn."Starting No." <= FirstFactCf) AND (rNoSeriesLn."Ending No." >= FirstFactCf)) AND
                    ((rNoSeriesLn."Starting Date" <= vFirstFechaFac) AND (rNoSeriesLn."Last Date Used" >= vFirstFechaFac)) THEN
                        vFirstFactCFAut := UPPERCASE(rNoSeriesLn.Series);
                    IF ((rNoSeriesLn."Starting No." <= LastFactCf) AND (rNoSeriesLn."Ending No." >= LastFactCf)) AND
                    ((rNoSeriesLn."Starting Date" <= vLastFechaFac) AND (rNoSeriesLn."Last Date Used" >= vLastFechaFac)) THEN
                        vLastFactCFAut := UPPERCASE(rNoSeriesLn.Series);
                UNTIL rNoSeriesLn.NEXT = 0;

            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := 'Del No.: ' + vFirstFactCFAut + ' ' + FirstFactCf;
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := 'Al No.: ' + vLastFactCFAut + ' ' + LastFactCf;
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;

        //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        VentasG := VentasG - TotalVentNcr + vTotalDocDevolucion + VentasEDevDocDev;
        //VENTAS GRAVADAS...
        DSTR1 := COPYSTR('#L##############    #R##################', 1);
        Value[1] := 'Ventas Gravadas:';
        Value[2] := '$' + FORMAT(VentasG, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        TotalIva := TotalIva - TotalIvaNcr + vTotalIvaDocDevolucion;
        //IMPUESTO IVA...
        DSTR1 := COPYSTR('#L###########       #R##################', 1);
        Value[1] := 'Impuesto IVA:';
        Value[2] := '$' + FORMAT(TotalIva - vCESC, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //IMPUESTO CESC...
        DSTR1 := COPYSTR('#L############           #R#############', 1);
        Value[1] := 'Impuesto CESC:';
        Value[2] := '$' + FORMAT(vCESC, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Total Gravado...
        DSTR1 := COPYSTR('#L############      #R##################', 1);
        Value[1] := 'Total Gravado:';
        Value[2] := '$' + FORMAT(VentasG + TotalIva, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //PERCEPCION...
        DSTR1 := COPYSTR('#L################# #R##################', 1);
        Value[1] := '(-) IVA Retenido:';
        Value[2] := '$' + FORMAT((Retencion - vTotalRetencionDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS EXENTAS...
        DSTR1 := COPYSTR('#L#############     #R##################', 1);
        Value[1] := 'Ventas Exentas:';
        Value[2] := '$' + FORMAT((VentasE - VentasEDev - VentasEDevDocDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS NO SUJETAS...
        DSTR1 := COPYSTR('#L################  #R##################', 1);
        Value[1] := 'Ventas No Sujetas:';
        Value[2] := '$' + FORMAT((VentasNoSu - VentasNoSuDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //TOTAL DOCUMENTO DEVOLUCION
        //VENTAS TOTALES
        DSTR1 := COPYSTR('#L#############     #R##################', 1);
        Value[1] := 'Ventas Totales:';
        Value[2] := '$' + FORMAT((VentasG + TotalIva + VentasE + VentasNoSu) - (VentasEDev + VentasNoSuDev + (Retencion - RetencionDev) + VentasEDevDocDev), 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        vVentasGravadasTotales := vVentasGravadasTotales + VentasG;
        vImpuestoIVATotales := vImpuestoIVATotales + TotalIva - vCESC;
        vCESCTotales := vCESCTotales + vCESC;
        vTotalGravadoTotales := vTotalGravadoTotales + (VentasG + TotalIva);
        vVentasExentasTotales := vVentasExentasTotales + (VentasE - VentasEDev);
        vVentasNoSujetasTotales := vVentasNoSujetasTotales + (VentasNoSu - VentasNoSuDev);
        vVentasTotalesTotales := vVentasTotalesTotales + ((VentasG + TotalIva + VentasE + VentasNoSu) - (VentasEDev + VentasNoSuDev + (Retencion - RetencionDev) + VentasEDevDocDev));
        vIVARetenidoTotales := vIVARetenidoTotales + (Retencion - RetencionDev);
        //LIMPIO LAS VARIABLES QUE MUESTRAN LOS TOTALES DE LAS VENTAS POR TIPO DE COMPROBANTES.
        CLEAR(Venta);
        CLEAR(Iva);
        CLEAR(vTotal);
        CLEAR(VentasG);
        CLEAR(TotalIva);
        CLEAR(TotalVentNcr);
        CLEAR(TotalIvaNcr);
        CLEAR(VentasE);
        CLEAR(VentasNoSu);
        CLEAR(VentasEDev);
        CLEAR(VentasNoSuDev);
        CLEAR(vTotalDocDevolucion);

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := 'VENTAS TOTALES';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS GRAVADAS TOTALES
        DSTR1 := COPYSTR('#L###################### #R#############', 1);
        Value[1] := 'Ventas Gravadas:';
        Value[2] := '$' + FORMAT(vVentasGravadasTotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //IMPUESTO IVA TOTALES
        DSTR1 := COPYSTR('#L###################### #R#############', 1);
        Value[1] := 'Impuesto IVA:';
        Value[2] := '$' + FORMAT(vImpuestoIVATotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //IMPUESTO CESC TOTALES
        DSTR1 := COPYSTR('#L###################### #R#############', 1);
        Value[1] := 'Impuesto CESC:';
        Value[2] := '$' + FORMAT(vCESCTotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //TOTAL GRAVADO TOTALES
        DSTR1 := COPYSTR('#L###################### #R#############', 1);
        Value[1] := 'Total Gravado:';
        Value[2] := '$' + FORMAT(vTotalGravadoTotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS EXENTAS TOTALES
        DSTR1 := COPYSTR('#L###################### #R#############', 1);
        Value[1] := 'Ventas Exentas:';
        Value[2] := '$' + FORMAT(vVentasExentasTotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS NO SUJETAS TOTALES
        DSTR1 := COPYSTR('#L###################### #R#############', 1);
        Value[1] := 'Ventas No Sujetas:';
        Value[2] := '$' + FORMAT(vVentasNoSujetasTotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //IVA PERCIBIDO TOTALES
        DSTR1 := COPYSTR('#L###################### #R#############', 1);
        Value[1] := '(+) IVA Percebido:';
        Value[2] := '$' + FORMAT(vIVAPercibidoTotales - vIVAPercibidoDevTotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //IVA RETENIDO TOTALES
        DSTR1 := COPYSTR('#L###################### #R#############', 1);
        Value[1] := '(-) IVA Retenido:';
        Value[2] := '$' + FORMAT(vIVARetenidoTotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //VENTAS TOTALES TOTALES
        DSTR1 := COPYSTR('#L###################### #R#############', 1);
        Value[1] := 'Ventas Totales:';
        Value[2] := '$' + FORMAT(vVentasTotalesTotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //TOTAL DEVOLUCIONES
        //ENCABEZADO PARA EL TIPO DE COMPROBANTE
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := 'DEVOLUCIONES';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
        Transaction2.RESET;
        Transaction2.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
        Transaction2.SETRANGE(Transaction2."POS Terminal No.", POSSESSION.TerminalNo());
        Transaction2.SETRANGE("Statement Code", SCode);
        Transaction2.SETRANGE("Z-Report ID", '');
        Transaction2.SETRANGE("Transaction Type", Transaction2."Transaction Type"::Sales);
        Transaction2.SETFILTER("Entry Status", '%1|%2', Transaction2."Entry Status"::" ", Transaction2."Entry Status"::Posted);
        Transaction2.SETRANGE("Sale Is Return Sale", TRUE);
        vNoDevoluciones := 0;
        IF Transaction2.FINDFIRST THEN BEGIN
            REPEAT
                vNoDevoluciones := (vNoDevoluciones + 1);
                CLEAR(Venta);
                CLEAR(Iva);
                CLEAR(vTotal);
                rSalesEntry.SETRANGE("Store No.", Transaction2."Store No.");
                rSalesEntry.SETRANGE("POS Terminal No.", Transaction2."POS Terminal No.");
                rSalesEntry.SETRANGE("Transaction No.", Transaction2."Transaction No.");
                IF rSalesEntry.FIND('-') THEN
                    REPEAT
                        IF rSalesEntry."FSN Remission No." <> '' THEN BEGIN
                            Venta += -(rSalesEntry."Net Amount");
                            Iva += -(rSalesEntry."VAT Amount");
                            vTotal += -(rSalesEntry."Net Amount") + -(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += -(rSalesEntry."Net Amount");
                                    TotalIva += -(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += -(rSalesEntry."Net Amount");
                                    TotalIvaNcr += -(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += -(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += -(rSalesEntry."Net Amount");
                                END;
                            END;
                        END ELSE BEGIN
                            Venta += ABS(rSalesEntry."Net Amount");
                            Iva += ABS(rSalesEntry."VAT Amount");
                            vTotal += ABS(rSalesEntry."Net Amount") + ABS(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += ABS(rSalesEntry."Net Amount");
                                    TotalIva += ABS(rSalesEntry."VAT Amount");
                                END ELSE BEGIN
                                    TotalVentNcr += ABS(rSalesEntry."Net Amount");
                                    TotalIvaNcr += ABS(rSalesEntry."VAT Amount");
                                END;
                            END ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += ABS(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += ABS(rSalesEntry."Net Amount");
                                END;
                            END;
                        END;
                    UNTIL rSalesEntry.NEXT = 0;
            UNTIL Transaction2.NEXT = 0;
        END;

        //DEVOLUCIONES...
        DSTR1 := COPYSTR('#L#################### #L#############', 1);
        Value[1] := 'Cantidad devoluciones:';
        Value[2] := FORMAT(vNoDevoluciones);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        VentasG := VentasG - TotalVentNcr;
        TotalIva := TotalIva - TotalIvaNcr;

        //VENTAS TOTALES
        DSTR1 := COPYSTR('#L################### #R################', 1);
        Value[1] := 'Devoluciones Totales:';
        Value[2] := '$' + FORMAT((VentasG + TotalIva + VentasE + VentasNoSu) - (VentasEDev + VentasNoSuDev) + vTotalRetencionDev - vIVAPercibidoDevTotales, 0, '<Integer Thousand><Decimals,3>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //LIMPIO LAS VARIABLES QUE MUESTRAN LOS TOTALES DE LAS VENTAS POR TIPO DE COMPROBANTES.
        CLEAR(FirstTicket);
        CLEAR(LastTicket);
        CLEAR(Venta);
        CLEAR(Iva);
        CLEAR(vTotal);
        CLEAR(VentasG);
        CLEAR(TotalIva);
        CLEAR(TotalVentNcr);
        CLEAR(TotalIvaNcr);
        CLEAR(VentasE);
        CLEAR(VentasNoSu);
        CLEAR(VentasEDev);
        CLEAR(VentasNoSuDev);

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        //contenido cortes fin
        vIVAS := vIVAPercibidoTotales - vIVAPercibidoDevTotales - vIVARetenidoTotales;
        //Se movio al final de los reportes
        CLEAR(PaymEntry);
        PaymEntry.SETCURRENTKEY("Statement Code", "Z-Report ID", "Tender Type", "Currency Code", "Card No.");
        PaymEntry.SETRANGE("Statement Code", SCode);
        PaymEntry.SETRANGE("Z-Report ID", '');
        PaymTrans3.COPYFILTERS(PaymEntry);

        TenderType.SETCURRENTKEY("Store No.");
        TenderType.SETRANGE("Store No.", Globals.StoreNo);
        TenderType.SETFILTER(TenderType."Function", '<>%1', TenderType."Function"::"Tender Remove/Float");
        TenderType.SETRANGE("Foreign Currency", TRUE);
        LocalTotal := 0;

        TenderType.SETRANGE("Foreign Currency");
        TenderType.SETRANGE(TenderType."Function", TenderType."Function"::"Tender Remove/Float");
        TenderType.SETRANGE(TenderType."Function", TenderType."Function"::"Tender Remove/Float");
        IF TenderType.FIND('-') THEN BEGIN
            PrintUL.PrintSeperator(2);
            REPEAT
                FOR lSafeType := 0 TO 3 DO BEGIN
                    NoOfLines := 0;
                    TotalSafeType := 0;
                    PaymEntry.SETRANGE("Safe type", lSafeType);
                    PaymEntry.SETRANGE("Currency Code");
                    PaymEntry.SETRANGE("Card No.");
                    PaymEntry.SETRANGE("Tender Type", TenderType.Code);
                    IF PaymEntry.FIND('-') THEN
                        REPEAT
                            NoOfLines := NoOfLines + 1;
                            Transaction.GET(PaymEntry."Store No.", PaymEntry."POS Terminal No.", PaymEntry."Transaction No.");
                            IF PaymEntry."Amount Tendered" > 0 THEN BEGIN
                                RemoveTotal := RemoveTotal + PaymEntry."Amount Tendered";
                            END
                            ELSE BEGIN
                                FloatTotal := FloatTotal + PaymEntry."Amount Tendered";
                            END;
                            TotalSafeType := TotalSafeType + PaymEntry."Amount Tendered";
                            LineFound := TRUE;
                        UNTIL PaymEntry.NEXT = 0;
                END;
            UNTIL TenderType.NEXT = 0;
        END;
        PaymEntry.SETRANGE("Safe type");

        IF FloatTotal <> 0 THEN BEGIN
            DSTR1 := '#C######################################';
            Value[1] := 'INGRESOS';
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            DSTR1 := '#L#############     #R##################';
            Value[1] := 'DESCRIPCIÓN';
            Value[2] := 'MONTO';
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            DSTR1 := '#L##############    #R##################';
            Value[1] := Text009 + ':';
            Value[2] := POSFunctions.FormatAmount(FloatTotal);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            DSTR1 := COPYSTR('                     ', 1);
            Value[1] := '';
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            DSTR1 := '#L######################### #R##########';
        END;

        DSTR1 := '#C######################################';
        Value[1] := 'RETIROS';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

        DSTR1 := '#L#############     #R##################';
        Value[1] := 'DESCRIPCIÓN';
        Value[2] := 'MONTO';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        TenderType.RESET;
        TenderType.SETRANGE("Store No.", Store."No.");
        TenderType.SETFILTER(TenderType.Code, '%1|%2', '1', '2');
        IF TenderType.FIND('-') THEN
            REPEAT
                PaymEntry.SETRANGE("Tender Type", TenderType.Code);
                PaymEntry.SETRANGE("Z-Report ID", '');
                PaymEntry.SetRange(PaymEntry."POS Terminal No.", POSSESSION.TerminalNo());
                PaymEntry.SETFILTER("Amount Tendered", '<%1', 0);
                PaymEntry.SETFILTER("Safe type", '=%1', PaymEntry."Safe type"::Bank);
                IF PaymEntry.FIND('-') THEN
                    REPEAT
                        rTransaction.RESET;
                        rTransaction.SETRANGE("Receipt No.", PaymEntry."Receipt No.");
                        rTransaction.FINDFIRST;
                        IF (rTransaction."Transaction Type" = rTransaction."Transaction Type"::"Remove Tender") OR
                        (rTransaction."Transaction Type" = rTransaction."Transaction Type"::"Tender Decl.") THEN BEGIN
                            IF (TenderType.Code = '1') THEN
                                vEfectivoRetirado := vEfectivoRetirado + (-PaymEntry."Amount Tendered")
                            ELSE
                                vChequeRetirado := vChequeRetirado + (-PaymEntry."Amount Tendered");
                        END;
                    UNTIL PaymEntry.NEXT = 0;
            UNTIL TenderType.NEXT = 0;

        IF (vEfectivoRetirado >= 0) THEN BEGIN
            DSTR1 := '#L###################### #R#############';
            Value[1] := TextEfectivoRetirado;
            Value[2] := POSFunctions.FormatAmount(vEfectivoRetirado);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;
        IF (vChequeRetirado >= 0) THEN BEGIN
            DSTR1 := '#L###################### #R#############';
            Value[1] := TextChequeRetirado;
            Value[2] := POSFunctions.FormatAmount(vChequeRetirado);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;

        // Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        Value[1] := '';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        DSTR1 := '#L######################### #R##########';

        //efectivo a retirar
        //Efectivo y cheque a retirar
        TenderType.RESET;
        TenderType.SETRANGE("Store No.", Store."No.");
        TenderType.SETFILTER(TenderType.Code, '%1|%2', '1', '2');
        IF TenderType.FIND('-') THEN
            REPEAT
                Transaction4.RESET;
                Transaction4.SETRANGE("Transaction Type", Transaction4."Transaction Type"::Sales);
                Transaction4.SETRANGE(Transaction4."POS Terminal No.", Terminal."No.");
                Transaction4.SETRANGE("Z-Report ID", '');
                //Transaction4.SETRANGE("Income/Exp. Amount", 0.0);
                IF Transaction4.FINDSET THEN
                    REPEAT
                        PaymEntry.RESET;
                        PaymEntry.SETRANGE("Z-Report ID", '');
                        PaymEntry.SETRANGE("Tender Type", TenderType.Code);
                        PaymEntry.SETFILTER("Safe type", '<>%1&<>%2', PaymEntry."Safe type"::Bank, PaymEntry."Safe type"::Safe);
                        PaymEntry.SETRANGE("Receipt No.", Transaction4."Receipt No.");
                        IF PaymEntry.FIND('-') THEN
                            REPEAT
                                IF (TenderType.Code = '1') THEN
                                    vEfectivoTotal := vEfectivoTotal + PaymEntry."Amount Tendered"
                                ELSE
                                    vChequeTotal := vChequeTotal + PaymEntry."Amount Tendered";
                            UNTIL PaymEntry.NEXT = 0;
                    UNTIL Transaction4.NEXT = 0;
            UNTIL TenderType.NEXT = 0;
        rTransSafeEntry.RESET;
        rTransSafeEntry.SETRANGE("Safe Type", rTransSafeEntry."Safe Type"::Safe);
        rTransSafeEntry.SETRANGE("Tender Type", '1');
        IF rTransSafeEntry.FIND('-') THEN BEGIN
            rTransSafeEntry.CALCSUMS("Amount Tendered");
            vCofreEfectivo := rTransSafeEntry."Amount Tendered";
        END;
        rTransSafeEntry.RESET;
        rTransSafeEntry.SETRANGE("Safe Type", rTransSafeEntry."Safe Type"::Safe);
        rTransSafeEntry.SETRANGE("Tender Type", '2');
        IF rTransSafeEntry.FIND('-') THEN BEGIN
            rTransSafeEntry.CALCSUMS("Amount Tendered");
            vCofreCheque := rTransSafeEntry."Amount Tendered";
        END;

        IF (vEfectivoTotal - ABS(vEfectivoRetirado) >= 0) THEN BEGIN
            DSTR1 := '#L########################## #R#########';
            Value[1] := TextEfectivoARetirar;
            //se quito el ivaretenido
            //se quito el ivapercibido
            Value[2] := POSFunctions.FormatAmount(vEfectivoTotal - ABS(vEfectivoRetirado));
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;
        IF (vChequeTotal - ABS(vChequeRetirado) >= 0) THEN BEGIN
            DSTR1 := '#L########################## #R#########';
            Value[1] := TextChequeARetirar;
            Value[2] := POSFunctions.FormatAmount(vChequeTotal - ABS(vChequeRetirado));
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;

        //mostrar cofre
        IF TRUE THEN BEGIN
            DSTR1 := '#L########################## #R#########';
            Value[1] := 'Cofre Efectivo';
            Value[2] := POSFunctions.FormatAmount(vCofreEfectivo);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            DSTR1 := '#L########################## #R#########';
            Value[1] := 'Cofre Cheque';
            Value[2] := POSFunctions.FormatAmount(vCofreCheque);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;

        CLEAR(PaymEntry);
        PaymEntry.SETCURRENTKEY("Statement Code", "Z-Report ID", "Tender Type", "Currency Code", "Card No.");
        PaymEntry.SETRANGE("Statement Code", SCode);
        PaymEntry.SETRANGE("Z-Report ID", '');
        PaymTrans3.COPYFILTERS(PaymEntry);

        TenderType.RESET;
        TenderType.SETCURRENTKEY("Store No.");
        TenderType.SETRANGE("Store No.", Globals.StoreNo);
        TenderType.SETFILTER(TenderType."Function", '<>%1', TenderType."Function"::"Tender Remove/Float");
        TenderType.SETRANGE("Foreign Currency", FALSE);
        LocalTotal := 0;
        LocalTotal := 0;

        PrintUL.PrintSeperator(2);
        PrintXZLines();
        Transaction."Transaction No." := 0;
        TendDeclEntry.SETCURRENTKEY("Statement Code", "Z-Report ID", "Tender Type", "Currency Code", "Card No.");
        TendDeclEntry.SETRANGE("Statement Code", SCode);
        TendDeclEntry.SETRANGE("Z-Report ID", '');
        IF Store."Tend. Decl. Calculation" = Store."Tend. Decl. Calculation"::Sum THEN BEGIN
            BufferTendDeclEntry;
            IF TendDeclEntry.FIND('-') THEN
                Transaction."Transaction No." := TendDeclEntry."Transaction No.";
        END
        ELSE BEGIN
            IF TendDeclEntry.FIND('-') THEN
                REPEAT
                    IF TendDeclEntry."Transaction No." > Transaction."Transaction No." THEN
                        Transaction.GET(TendDeclEntry."Store No.", TendDeclEntry."POS Terminal No.", TendDeclEntry."Transaction No.")
                UNTIL TendDeclEntry.NEXT = 0;
        END;

        IF Transaction."Transaction No." <> 0 THEN BEGIN
            PrintUL.PrintLine(2, PrintUL.FormatLine(Text112, FALSE, TRUE, FALSE, FALSE));
            CLEAR(TendDeclEntry);
            LocalTotal := 0;
            IF Store."Tend. Decl. Calculation" = Store."Tend. Decl. Calculation"::Last THEN BEGIN
                TendDeclEntry.SETCURRENTKEY("Store No.", "POS Terminal No.", "Transaction No.");
                TendDeclEntry.SETRANGE("Store No.", Transaction."Store No.");
                TendDeclEntry.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
                TendDeclEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
                BufferTendDeclEntry;
            END;
            TempTendDeclEntry.SETFILTER("Currency Code", '=%1', '');
            PrintTenderDeclLines;
            Transaction."Gross Amount" := -LocalTotal;
            PrintTotal(Transaction, 2, 0);
            PrintUL.PrintLine(2, '');
            TempTendDeclEntry.SETFILTER("Currency Code", '<>%1', '');
            PrintTenderDeclLines;
        END;
        AmountTotal := 0;
        DiscoutAmount := 0;//20240325
        // Sales and Discount Totals
        Transaction.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
        Transaction.SETRANGE(Transaction."POS Terminal No.", POSSESSION.TerminalNo());
        Transaction.SETRANGE("Statement Code", SCode);
        Transaction.SETRANGE("Z-Report ID", '');
        Transaction.SETRANGE("Transaction Type", Transaction."Transaction Type"::Sales);
        Transaction.SETFILTER("Entry Status", '%1|%2', Transaction."Entry Status"::" ", Transaction."Entry Status"::Posted);
        //Transaction.CALCSUMS("Gross Amount", "Discount Amount", "Total Discount", Rounded, "No. of Items");
        IF Transaction.FINd('-') THEN BEGIN
            REPEAT
                DiscoutAmount := DiscoutAmount + Transaction."Discount Amount";
                PaymentFilt.RESET;
                PaymentFilt.SETRANGE("Store No.", Transaction."Store No.");
                PaymentFilt.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
                PaymentFilt.SETRANGE("Transaction No.", Transaction."Transaction No.");
                //PaymentFilt.SETRANGE("Tender Type", TenderType.Code);
                PaymentFilt.SETRANGE(PaymentFilt."Safe type", PaymentFilt."Safe type"::" ");
                PaymentFilt.SETRANGE("Receipt No.", Transaction."Receipt No.");
                IF PaymentFilt.FIND('-') THEN
                    repeat
                        AmountTotal := AmountTotal + PaymentFilt."Amount Tendered";
                    until PaymentFilt.Next() = 0;
            until Transaction.Next() = 0;
        END;

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        Value[1] := '';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        DSTR1 := '#L######################### #R##########';
        Value[1] := 'Total Medios de Pago:';
        //Value[2] := POSFunctions.FormatAmount(-Transaction."Gross Amount" + Transaction.Rounded + vIVAS);
        Value[2] := POSFunctions.FormatAmount(AmountTotal + vIVAS);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        PrintUL.PrintSeperator(2);

        DSTR1 := '#L######################### #R##########';
        Value[2] := POSFunctions.FormatAmount(AmountTotal + DiscoutAmount + vIVAS);
        //Value[2] := POSFunctions.FormatAmount(-Transaction."Gross Amount" + Transaction."Discount Amount" + vIVAS);
        Value[1] := 'Ventas Brutas:';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Value[2] := POSFunctions.FormatAmount(-Transaction."Discount Amount");
        Value[2] := POSFunctions.FormatAmount(DiscoutAmount);
        Value[1] := 'Descuento';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        IncExpAccount.SETRANGE(IncExpAccount."Store No.", Globals.StoreNo);
        IF IncExpAccount.FIND('-') THEN BEGIN
            IncExpEntry.SETCURRENTKEY("Statement Code", "Z-Report ID", "No.");
            IncExpEntry.SETRANGE("Statement Code", SCode);
            IncExpEntry.SETRANGE("Z-Report ID", '');
            IF IncExpEntry.FIND('-') THEN BEGIN
                PrintUL.PrintSeperator(2);
                DSTR1 := '#C######################################';
                Value[1] := 'FONDOS AJENOS';
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                DSTR1 := '#L#############     #R##################';
                Value[1] := 'DESCRIPCIÓN';
                Value[2] := 'MONTO';
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                DSTR1 := '#L########################## #R#########';
                REPEAT
                    IncExpEntry.SETRANGE("No.", IncExpAccount."No.");
                    IF IncExpEntry.FIND('-') THEN BEGIN
                        Value[1] := IncExpAccount.Description;
                        IncExpEntry.CALCSUMS(Amount);
                        Value[2] := POSFunctions.FormatAmount(IncExpEntry.Amount);
                        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END;
                UNTIL IncExpAccount.NEXT = 0;
            END;
        END;

        PrintUL.PrintSeperator(2);

        //Transaction counting
        IF PaymTrans3.FIND('-') THEN
            REPEAT
                IF NOT PaymTemp.GET(PaymTrans3."Store No.", PaymTrans3."POS Terminal No.", PaymTrans3."Transaction No.") THEN BEGIN
                    Transaction2.GET(PaymTrans3."Store No.", PaymTrans3."POS Terminal No.", PaymTrans3."Transaction No.");
                    IF Transaction2."Transaction Type" = Transaction2."Transaction Type"::Sales THEN
                        RecCount := RecCount + 1;
                    PaymTemp."Store No." := PaymTrans3."Store No.";
                    PaymTemp."POS Terminal No." := PaymTrans3."POS Terminal No.";
                    PaymTemp."Transaction No." := PaymTrans3."Transaction No.";
                    PaymTemp.INSERT;
                END;
            UNTIL PaymTrans3.NEXT = 0;
        Value[1] := 'No. de transacciones:';
        Value[2] := FORMAT(Transaction.COUNT, 0, '<Integer>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        Value[1] := 'Articulos vendidos:';
        Value[2] := FORMAT(Transaction."No. of Items", 0, '<Integer>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        Transaction.SETRANGE(Transaction."Sale Is Return Sale", TRUE);
        Value[1] := 'No. de devoluciones:';
        Value[2] := FORMAT(Transaction.COUNT, 0, '<Integer>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        Transaction.SETRANGE(Transaction."Sale Is Return Sale");

        SuspTrans.SETRANGE("Store No.", Store."No.");
        SuspTrans.SETRANGE("Entry Status", SuspTrans."Entry Status"::Suspended);
        NoSuspended := SuspTrans.COUNT;
        Value[1] := 'No. de suspenciones:';
        Value[2] := FORMAT(NoSuspended, 0, '<Integer>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        SuspTrans.SETRANGE("Store No.");

        IF (NoSuspended > 0) THEN BEGIN
            IF Terminal."Print Suspend with Prepayment" THEN BEGIN
                NoSuspPrepayment := 0;
                SuspPrepayment := 0;

                SuspTransLine.RESET;
                SuspTransLine.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
                SuspTransLine.SETRANGE("Entry Type", SuspTransLine."Entry Type"::IncomeExpense);
                IF SuspTransLine.FIND('-') THEN BEGIN
                    REPEAT
                        IF (SuspTransLine."POS Terminal No." = '0') THEN BEGIN
                            NoSuspPrepayment := NoSuspPrepayment + 1;
                            SuspPrepayment := SuspPrepayment + SuspTransLine.Amount;
                        END;
                    UNTIL SuspTransLine.NEXT = 0;
                END;
                SuspPrepayment := ABS(SuspPrepayment);
                IF (NoSuspPrepayment > 0) THEN BEGIN
                END;
                IF (SuspPrepayment > 0) THEN BEGIN
                END;
            END;
        END;

        Transaction.SETRANGE("Entry Status", Transaction."Entry Status"::Voided);
        Value[1] := 'No. de anulaciones:';
        Value[2] := FORMAT(Transaction.COUNT, 0, '<Integer>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        IF gNoSuspPOSTransactionsVoided <> 0 THEN BEGIN
            Value[1] := '  ' + Text230;
            Value[2] := FORMAT(gNoSuspPOSTransactionsVoided, 0, '<Integer>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
        END;

        Transaction.SETRANGE("Entry Status", Transaction."Entry Status"::Training);
        Transaction.SETRANGE("Entry Status");

        Transaction.SETFILTER("Transaction Type", '%1|%2',
        Transaction."Transaction Type"::Sales, Transaction."Transaction Type"::"Open Drawer");
        Transaction.SETRANGE("Open Drawer", TRUE);
        Transaction.SETRANGE("Open Drawer");

        Transaction.SETRANGE("Transaction Type", Transaction."Transaction Type"::Logon);
        Transaction.SETRANGE("Transaction Type");

        IF Transaction."No. of Covers" <> 0 THEN BEGIN
            Value[1] := Text235;
            Value[2] := FORMAT(Transaction."No. of Covers", 0, '<Integer>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

            Transaction.SETFILTER("Split Number", '<>%1', 0);
            NoSplitTrans := Transaction.COUNT;
            Value[1] := Text236;
            Value[2] := FORMAT(NoSplitTrans, 0, '<Integer>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
            Transaction.SETRANGE("Split Number");

            NoTables := RecCount - NoSplitTrans;

            Value[1] := Text237;
            Value[2] := FORMAT(Transaction."No. of Covers" / NoTables, 0, '<Integer>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

            Value[1] := Text238;
            Value[2] := FORMAT(RecCount / NoTables, 0, '<Integer>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
        END;

        IF WHBatchQueue.COUNT > 0 THEN BEGIN
            Value[1] := lText004;
            Value[2] := FORMAT(WHBatchQueue.COUNT, 0, '<Integer>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));
        END;

        IF GenPosFunc."TS Send Transactions" AND (GenPosFunc."Send Transaction" <> '') THEN BEGIN
            TransServerWorkTable.RESET;
            TransServerWorkTable.SETRANGE(Table, DATABASE::"LSC Transaction Header");
            TransServerWorkTable.SETRANGE("Store No.", Globals.StoreNo);
            TransServerWorkTable.SETRANGE("POS Terminal No.", Globals.TerminalNo);
            TransNotSent := TransServerWorkTable.COUNT;
            IF TransNotSent > 0 THEN BEGIN
                PrintUL.PrintSeperator(2);
                CLEAR(Value);
                DSTR1 := '#L######################################';
                Value[1] := Text153;
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                Value[1] := STRSUBSTNO(Text161, TransNotSent);
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                PrintUL.PrintSeperator(2);
            END;
        END;
        Commit();
        IF NOT PrintUL.ClosePrinter(2) THEN //Error .Run
            EXIT(FALSE);

        IF Transaction."Entry Status" = Transaction."Entry Status"::Training THEN
            EXIT(TRUE);

        Terminal."FSN Last X-Report" := INCSTR(Terminal."FSN Last X-Report");
        Terminal.MODIFY;
        EXIT(TRUE);

    end;

    procedure PrintXZLines()
    var
        DSTR1: Text[80];
        Currency: Record "Currency";
        TTCardSetup: Record "LSC Tender Type Card Setup";
        vEfectivoTotalVentas: Decimal;
        vChequeTotalVentas: Decimal;
        vOtroTotal: Decimal;
        rTransHeader: Record "LSC Transaction Header";
        rPaymentEntry: Record "LSC Trans. Payment Entry";
        Currency_l: Record "LSC Tender Type Currency Setup";
        PaymentEntry_l: Record "LSC Trans. Payment Entry";
        TenderTypeSetup_l: Record "LSC Tender Type Setup";
        POSCardEntry_l: Record "LSC POS Card Entry";
        StoreTotaCard: Decimal;
        OfflineTotalCard: Decimal;
        lText001: Label 'In Store';
        lText002: Label 'Call Center';
        IsCardFunction: Boolean;
        CashDeclTmp3: Record "LSC POS Cash Declaration" temporary;
        PosTrans: Record "LSC POS Transaction";
        CashDeclTmp2: Record "LSC POS Cash Declaration" temporary;
    begin
        //PrintXZLines
        TTCardSetup.SETCURRENTKEY("Store No.", "Tender Type Code");
        TTCardSetup.SETRANGE("Store No.", Globals.StoreNo);
        IF TenderType.FIND('-') THEN BEGIN
            IF TenderType."Foreign Currency" THEN BEGIN
            END
            ELSE BEGIN
                DSTR1 := '#C######################################';
                Value[1] := 'MEDIOS DE PAGO';
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

                DSTR1 := '#L#############     #R##################';
                Value[1] := 'DESCRIPCIÓN';
                Value[2] := 'MONTO';
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END;
            REPEAT
                vEfectivoTotalVentas := 0;
                vChequeTotalVentas := 0;
                vOtroTotal := 0;
                IsCardFunction := FALSE;
                OfflineTotalCard := 0;
                StoreTotaCard := 0;

                Value[2] := '';
                PaymEntry.SETRANGE("Tender Type", TenderType.Code);
                PaymEntry.SetRange("POS Terminal No.", POSSESSION.TerminalNo());
                PaymEntry.SETRANGE("Card No.");
                Value[1] := TenderType.Description;
                LocalTotal := LocalTotal + PaymEntry."Amount Tendered";

                IF (TenderType."Foreign Currency") THEN BEGIN
                    PaymEntry.SETRANGE("Currency Code");
                    IF POSSESSION.StoreNo = TenderType."Store No." THEN BEGIN
                        Currency_l.RESET;
                        Currency_l.SETRANGE(Currency_l."Store No.", TenderType."Store No.");
                        Currency_l.SETRANGE(Currency_l."Tender Type Code", TenderType.Code);
                        IF Currency_l.FIND('-') THEN
                            DSTR1 := '#L#### #R########### #R#################';
                        REPEAT
                            PaymentEntry_l.RESET;
                            PaymentEntry_l.SETCURRENTKEY("Statement Code", "Z-Report ID", "Tender Type", "Currency Code", "Card No.", "Y-Report ID");
                            PaymentEntry_l.SETRANGE(PaymentEntry_l."Z-Report ID", '');
                            PaymentEntry_l.SETRANGE(PaymentEntry_l."Tender Type", TenderType.Code);
                            PaymentEntry_l.SetRange(PaymentEntry_l."POS Terminal No.", POSSESSION.TerminalNo());
                            PaymentEntry_l.SETRANGE(PaymentEntry_l."Currency Code", Currency_l."Currency Code");
                            PaymentEntry_l.SETRANGE(PaymentEntry_l."Safe type", PaymentEntry_l."Safe type"::" ");
                            PaymentEntry_l.CALCSUMS("Amount Tendered", "Amount in Currency");
                            IF PaymentEntry_l."Amount Tendered" <> 0 THEN BEGIN
                                Value[1] := Currency_l."Currency Code";
                                Value[2] := POSFunctions.FormatCurrency(PaymentEntry_l."Amount in Currency", Currency_l."Currency Code");
                                Value[3] := POSFunctions.FormatAmount(PaymentEntry_l."Amount Tendered");
                                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;
                            TotalLCYInCurrency := TotalLCYInCurrency + PaymentEntry_l."Amount Tendered";
                        UNTIL Currency_l.NEXT = 0;
                    END;
                END ELSE BEGIN
                    IF (TenderType."Function" = TenderType."Function"::Card) THEN BEGIN
                        PaymEntry.SETRANGE("Card No.");
                        PaymEntry.CALCSUMS("Amount Tendered");
                        IF PaymEntry."Amount Tendered" <> 0 THEN BEGIN
                            DSTR1 := '#L################# #R##################';
                            Value[2] := POSFunctions.FormatAmount(PaymEntry."Amount Tendered");
                            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            TTCardSetup.SETRANGE("Tender Type Code", TenderType.Code);
                            IF TTCardSetup.FIND('-') THEN
                                REPEAT
                                    DSTR1 := '   #L######### #R####### #R#############';
                                    PaymEntry.SETRANGE("Card No.", TTCardSetup."Card No.");
                                    PaymEntry.CALCSUMS("Amount Tendered");
                                    IF PaymEntry."Amount Tendered" <> 0 THEN BEGIN
                                        Value[1] := TTCardSetup.Description;
                                        Value[2] := '';
                                        Value[3] := POSFunctions.FormatAmount(PaymEntry."Amount Tendered");
                                        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                    END
                                UNTIL TTCardSetup.NEXT = 0;
                        END;
                    END ELSE BEGIN
                        IF TenderTypeSetup_l.GET(TenderType.Code) THEN
                            IsCardFunction := TenderTypeSetup_l."FSN Function in CC" = TenderTypeSetup_l."FSN Function in CC"::Card;

                        DSTR1 := '#L################## #R## #R############';
                        rTransHeader.RESET;
                        rTransHeader.SETRANGE("Transaction Type", rTransHeader."Transaction Type"::Sales);
                        rTransHeader.SETRANGE(rTransHeader."Store No.", POSSESSION.StoreNo());
                        rTransHeader.SETRANGE(rTransHeader."POS Terminal No.", POSSESSION.TerminalNo());
                        rTransHeader.SETRANGE("Z-Report ID", '');
                        //rTransHeader.SETRANGE("Income/Exp. Amount", 0.0);
                        IF rTransHeader.FINDSET THEN
                            REPEAT
                                rPaymentEntry.RESET;
                                rPaymentEntry.SETRANGE("Store No.", rTransHeader."Store No.");
                                rPaymentEntry.SETRANGE("POS Terminal No.", rTransHeader."POS Terminal No.");
                                rPaymentEntry.SETRANGE("Transaction No.", rTransHeader."Transaction No.");
                                rPaymentEntry.SETRANGE("Tender Type", TenderType.Code);
                                rPaymentEntry.SETRANGE(rPaymentEntry."Safe type", rPaymentEntry."Safe type"::" ");
                                rPaymentEntry.SETRANGE("Receipt No.", rTransHeader."Receipt No.");
                                IF rPaymentEntry.FIND('-') THEN
                                    REPEAT //Change BEGIN to REPEAT 
                                        IF (TenderType.Code = '1') THEN
                                            vEfectivoTotalVentas := vEfectivoTotalVentas + rPaymentEntry."Amount Tendered"
                                        ELSE
                                            IF (TenderType.Code = '2') THEN
                                                vChequeTotalVentas := vChequeTotalVentas + rPaymentEntry."Amount Tendered"
                                            ELSE
                                                vOtroTotal := vOtroTotal + rPaymentEntry."Amount Tendered";

                                        IF IsCardFunction THEN begin
                                            POSCardEntry_l.Reset();
                                            POSCardEntry_l.SetRange("Store No.", rPaymentEntry."Store No.");
                                            POSCardEntry_l.SetRange("POS Terminal No.", rPaymentEntry."POS Terminal No.");
                                            POSCardEntry_l.SetRange("Receipt No.", rPaymentEntry."Receipt No.");
                                            IF POSCardEntry_l.FindFirst() THEN BEGIN
                                                IF (POSCardEntry_l."Transaction Type" IN [POSCardEntry_l."Transaction Type"::Offline, POSCardEntry_l."Transaction Type"::"Void Offline"])
                                                  AND POSCardEntry_l."MSR input" AND POSCardEntry_l."Authorisation Ok" THEN
                                                    OfflineTotalCard += rPaymentEntry."Amount Tendered"
                                                ELSE
                                                    StoreTotaCard += rPaymentEntry."Amount Tendered";
                                            END ELSE
                                                StoreTotaCard += rPaymentEntry."Amount Tendered";
                                        end;
                                    UNTIL rPaymentEntry.NEXT = 0; //WVILLALTA21OCT19+
                            UNTIL rTransHeader.NEXT = 0;
                        IF TRUE THEN BEGIN
                            IF (TenderType.Code = '1') THEN
                                Value[3] := POSFunctions.FormatAmount(vEfectivoTotalVentas)
                            ELSE
                                IF (TenderType.Code = '2') THEN
                                    Value[3] := POSFunctions.FormatAmount(vChequeTotalVentas)
                                ELSE
                                    Value[3] := POSFunctions.FormatAmount(vOtroTotal);

                            IF (((vEfectivoTotalVentas) <> 0) OR (vChequeTotalVentas <> 0) OR (vOtroTotal <> 0)) THEN BEGIN
                                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                //ANALISIS
                                IF IsCardFunction THEN BEGIN
                                    DSTR1 := '   #L######### #R####### #R#############';
                                    Value[1] := lText001;
                                    Value[2] := POSFunctions.FormatAmount(StoreTotaCard);
                                    Value[3] := '';
                                    PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                    Value[1] := lText002;
                                    Value[2] := POSFunctions.FormatAmount(OfflineTotalCard);
                                    Value[3] := '';
                                    PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                                END;
                            END;
                        END;
                    END;
                END;
            UNTIL TenderType.NEXT = 0;

            IF FillPrintCIDDelivery(CashDeclTmp3, PosTrans) THEN BEGIN
                CashDeclTmp3.RESET;
                CashDeclTmp3.SETRANGE(CashDeclTmp3.Uncounted, FALSE);
                IF CashDeclTmp3.FIND('-') THEN
                    PrintUL.PrintSeperator(2);
                REPEAT
                    CashDeclTmp2.RESET;
                    CashDeclTmp2.SETRANGE(CashDeclTmp2."Tender Type", CashDeclTmp3."Tender Type");
                    IF NOT CashDeclTmp2.FIND('-') THEN BEGIN
                        Value[1] := CashDeclTmp3.Description;
                        Value[2] := POSFunctions.FormatAmount(CashDeclTmp3.Amount);
                        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END;
                UNTIL CashDeclTmp3.NEXT = 0;
            END;
        end;
    end;

    procedure FillPrintCIDDelivery(var pCashDeclTmp3: Record "LSC POS Cash Declaration" temporary; pPosTrans: Record "LSC POS Transaction"): Boolean
    var
        DeliveryTrip: Record "FSN Delivery Trip";
        TransPayment: Record "LSC Trans. Payment Entry";
        TransHdr: Record "LSC Transaction Header";
        TenderTypeStp: Record "LSC Tender Type Setup";
        TenderType_l: Record "LSC Tender Type";
    begin
        pCashDeclTmp3.RESET;
        pCashDeclTmp3.DELETEALL;
        CLEAR(pCashDeclTmp3);

        DeliveryTrip.RESET;
        DeliveryTrip.SETRANGE(DeliveryTrip."Store No.", POSSESSION.StoreNo);
        DeliveryTrip.SETRANGE(DeliveryTrip."POS Terminal No.", POSSESSION.TerminalNo);
        DeliveryTrip.SETRANGE(DeliveryTrip."Trip. Status", DeliveryTrip."Trip. Status"::"Trip Starting");
        DeliveryTrip.SETRANGE(DeliveryTrip."General Status", DeliveryTrip."General Status"::InProcess);
        IF DeliveryTrip.FIND('-') THEN BEGIN
            REPEAT
                TransHdr.RESET;
                TransHdr.SETCURRENTKEY("Receipt No.", Date);
                TransHdr.SETRANGE(TransHdr."Receipt No.", DeliveryTrip."Order No.");
                IF TransHdr.FINDFIRST THEN BEGIN
                    TransPayment.RESET;
                    TransPayment.SETCURRENTKEY("Store No.", "POS Terminal No.", "Transaction No.", "Line No.");
                    TransPayment.SETRANGE(TransPayment."Store No.", TransHdr."Store No.");
                    TransPayment.SETRANGE(TransPayment."POS Terminal No.", TransHdr."POS Terminal No.");
                    TransPayment.SETRANGE(TransPayment."Transaction No.", TransHdr."Transaction No.");
                    IF TransPayment.FINDFIRST THEN
                        REPEAT
                            IF TenderTypeStp.GET(TransPayment."Tender Type") AND
                              VerifyTenderForDriverAmt(TenderTypeStp, 0) THEN BEGIN
                                IF NOT pCashDeclTmp3.GET(pPosTrans."Receipt No.", TransPayment."Tender Type", TransPayment."Currency Code", TransPayment."Card No.") THEN BEGIN
                                    pCashDeclTmp3.INIT;
                                    pCashDeclTmp3."Receipt No." := pPosTrans."Receipt No.";
                                    pCashDeclTmp3."Tender Type" := TransPayment."Tender Type";
                                    pCashDeclTmp3."Currency Code" := TransPayment."Currency Code";
                                    pCashDeclTmp3."Card No." := TransPayment."Card No.";
                                    pCashDeclTmp3.Description := COPYSTR(TenderTypeStp.Description + '(En Ruta)', 1, MAXSTRLEN(pCashDeclTmp3.Description));
                                    IF TenderType_l.GET(TransPayment."Store No.", TransPayment."Tender Type") THEN
                                        pCashDeclTmp3.Description := COPYSTR(TenderType_l.Description + '(En Ruta)', 1, MAXSTRLEN(pCashDeclTmp3.Description));
                                    pCashDeclTmp3."First Float Entry" := TenderTypeStp."FSN Function in CC" = TenderTypeStp."FSN Function in CC"::Change;
                                    pCashDeclTmp3.INSERT;
                                END;
                                pCashDeclTmp3.Amount += TransPayment."Amount Tendered";
                                pCashDeclTmp3.MODIFY;
                            END;
                        UNTIL TransPayment.NEXT = 0;
                    exit(TRUE);
                END;
                IF DeliveryTrip.Change > 0 THEN BEGIN
                    pCashDeclTmp3.SETRANGE(pCashDeclTmp3."First Float Entry", TRUE);
                    IF pCashDeclTmp3.FIND('-') THEN BEGIN
                        pCashDeclTmp3.Amount += DeliveryTrip.Change;
                        pCashDeclTmp3.MODIFY;
                    END;
                    pCashDeclTmp3.RESET;
                END;
            UNTIL DeliveryTrip.NEXT = 0;
        END;
        EXIT(FALSE);
    end;

    procedure VerifyTenderForDriverAmt(pTenderTypeSetup: Record "LSC Tender Type Setup"; pFilter: Integer): Boolean
    begin
        EXIT(pTenderTypeSetup."FSN Function in CC" IN [pTenderTypeSetup."FSN Function in CC"::Check
                                              , pTenderTypeSetup."FSN Function in CC"::Card
                                             , pTenderTypeSetup."FSN Function in CC"::Change]);
    end;

    procedure BufferTendDeclEntry()
    var

        TransInfoCode: Record "LSC Trans. Infocode Entry";
    begin
        //BufferTendDeclEntry

        TempTendDeclEntry.RESET;
        TempTendDeclEntry.DELETEALL;
        TempTransInfoCode.RESET;
        TempTransInfoCode.DELETEALL;

        TempTendDeclEntry.SETCURRENTKEY("Statement Code", "Z-Report ID", "Tender Type", "Currency Code", "Card No.");
        IF TendDeclEntry.FIND('-') THEN BEGIN
            REPEAT
                TempTendDeclEntry.SETRANGE("Statement Code", TendDeclEntry."Statement Code");
                TempTendDeclEntry.SETRANGE("Z-Report ID", TendDeclEntry."Z-Report ID");
                TempTendDeclEntry.SETRANGE("Tender Type", TendDeclEntry."Tender Type");
                TempTendDeclEntry.SETRANGE("Currency Code", TendDeclEntry."Currency Code");
                TempTendDeclEntry.SETRANGE("Card No.", TendDeclEntry."Card No.");
                IF TempTendDeclEntry.FIND THEN BEGIN
                    TempTendDeclEntry."Amount Tendered" += TendDeclEntry."Amount Tendered";
                    TempTendDeclEntry.Quantity += TendDeclEntry.Quantity;
                    TempTendDeclEntry."Amount in Currency" += TendDeclEntry."Amount in Currency";
                    TempTendDeclEntry.MODIFY;
                END ELSE BEGIN
                    TempTendDeclEntry := TendDeclEntry;
                    TempTendDeclEntry.INSERT;
                END;

                TransInfoCode.SETRANGE("Store No.", TendDeclEntry."Store No.");
                TransInfoCode.SETRANGE("POS Terminal No.", TendDeclEntry."Store No.");
                TransInfoCode.SETRANGE("Transaction No.", TendDeclEntry."Transaction No.");
                TransInfoCode.SETRANGE("Transaction Type", TransInfoCode."Transaction Type"::"Payment Entry");
                TransInfoCode.SETRANGE("Line No.", TendDeclEntry."Line No.");
                IF TransInfoCode.FIND('-') THEN
                    REPEAT
                        TempTransInfoCode := TransInfoCode;
                        TempTransInfoCode."Replication Counter" := TempTendDeclEntry."Line No.";
                        TempTransInfoCode.INSERT;
                    UNTIL TransInfoCode.NEXT = 0;

            UNTIL TendDeclEntry.NEXT = 0;
        END;

        TempTendDeclEntry.RESET;
        TempTendDeclEntry.SETCURRENTKEY("Statement Code", "Z-Report ID", "Tender Type", "Currency Code", "Card No.");
    end;

    procedure PrintTenderDeclLines()
    var
        DSTR1: Text[50];
        Payment: Text[30];
        TenderType: Record "LSC Tender Type";
        TenderCard: Record "LSC Tender Type Card Setup";
        TransInfoCode: Record "LSC Trans. Infocode Entry";
        Currency: Record "Currency";
        TransDiffEntry: Record "LSC Trans. Difference Entry";
    begin
        //PrintTenderDeclLines
        DSTR1 := '#L######## #R### #R######## #R##########';

        IF TempTendDeclEntry.FIND('-') THEN
            REPEAT
                LocalTotal := LocalTotal + TempTendDeclEntry."Amount Tendered";
                Payment := TempTendDeclEntry."Tender Type";
                IF TenderType.GET(TempTendDeclEntry."Store No.", TempTendDeclEntry."Tender Type") THEN
                    Payment := TenderType.Description
                ELSE
                    CLEAR(TenderType);

                CLEAR(Value);
                IF TenderType."Foreign Currency" THEN BEGIN
                    Value[1] := TempTendDeclEntry."Currency Code";
                    NodeName[1] := 'Currency Code';
                    NodeName[2] := 'x';
                    NodeName[3] := 'x';
                    IF TenderType."Multiply in Tender Operations" THEN BEGIN
                        Value[2] := POSFunctions.FormatQty(TempTendDeclEntry.Quantity);
                        NodeName[2] := 'Quantity';
                        Value[3] := POSFunctions.FormatAmount(TempTendDeclEntry."Amount in Currency" / TempTendDeclEntry.Quantity);
                        NodeName[3] := 'Tender Unit Value';
                    END;
                    Value[4] := POSFunctions.FormatCurrency(TempTendDeclEntry."Amount in Currency", Value[1]);
                    NodeName[4] := 'Amount In Currency';
                END ELSE BEGIN
                    Value[1] := Payment;
                    IF (TenderType."Function" = TenderType."Function"::Card) THEN
                        IF TenderCard.GET(TempTendDeclEntry."Store No.", TempTendDeclEntry."Tender Type", TempTendDeclEntry."Card No.") THEN
                            IF TenderCard.Description <> '' THEN
                                Value[1] := TenderCard.Description;
                    NodeName[1] := 'Tender Description';
                    NodeName[2] := 'x';
                    NodeName[3] := 'x';
                    IF TenderType."Multiply in Tender Operations" THEN BEGIN
                        Value[2] := POSFunctions.FormatQty(TempTendDeclEntry.Quantity);
                        NodeName[2] := 'Quantity';
                        Value[3] := POSFunctions.FormatAmount(TempTendDeclEntry."Amount Tendered" / TempTendDeclEntry.Quantity);
                        NodeName[3] := 'Tender Unit Value';
                    END;
                    Value[4] := POSFunctions.FormatAmount(TempTendDeclEntry."Amount Tendered");
                    NodeName[4] := 'Amount In Tender';
                END;
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                PrintUL.AddPrintLine(700, 4, NodeName, Value, DSTR1, FALSE, FALSE, FALSE, FALSE, 2);
                TransDiffEntry.SETRANGE("Store No.", TempTendDeclEntry."Store No.");
                TransDiffEntry.SETRANGE("POS Terminal No.", TempTendDeclEntry."POS Terminal No.");
                TransDiffEntry.SETRANGE("Transaction No.", TempTendDeclEntry."Transaction No.");
                TransDiffEntry.SETRANGE("Tender Type", TempTendDeclEntry."Tender Type");
                TransDiffEntry.SETRANGE("Currency Code", TempTendDeclEntry."Currency Code");

                IF TransDiffEntry.FINDFIRST THEN BEGIN
                    Value[1] := DiffText;
                    NodeName[1] := 'Tender Description';
                    NodeName[2] := 'x';
                    NodeName[3] := 'x';
                    Value[4] := POSFunctions.FormatAmount(TransDiffEntry.Amount);
                    NodeName[4] := 'Amount In Tender';

                    PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    PrintUL.AddPrintLine(700, 4, NodeName, Value, DSTR1, FALSE, FALSE, FALSE, FALSE, 2);
                END;
                TempTransInfoCode.SETCURRENTKEY("Replication Counter");
                TempTransInfoCode.SETRANGE("Replication Counter", TempTendDeclEntry."Line No.");
                IF TempTransInfoCode.FINDSET THEN
                    REPEAT
                        TransInfoCode.GET(
                          TempTransInfoCode."Store No.", TempTransInfoCode."POS Terminal No.", TempTransInfoCode."Transaction No.",
                          TempTransInfoCode."Transaction Type", TempTransInfoCode."Line No.",
                          TempTransInfoCode.Infocode, TempTransInfoCode."Entry Line No.");
                        PrintUL.PrintTransInfoCode(TransInfoCode, 2, FALSE);
                    UNTIL TempTransInfoCode.NEXT = 0;
            UNTIL TempTendDeclEntry.NEXT = 0;
    end;

    procedure PrintTotal(Transaction: Record "LSC Transaction Header"; Tray: Integer; RightIndent: Integer): Boolean
    var
        DSTR1: Text[50];
        SecTotal: Decimal;
        CurrencyExchRate: Record "Currency Exchange Rate";
        Total: Decimal;
        TotalAmtForSummary: Decimal;
        gltesttotal: Label 'gl total';
        SecSubTotal: Decimal;
    begin
        //PrintTotal
        CLEAR(Value);
        CLEAR(Currency);

        Total := -Transaction."Gross Amount" - Transaction."Income/Exp. Amount" + totSPOAmount;

        IF GenPosFunc."Display Secondary Total Curr" AND (GenPosFunc."Secondary Total Currency" <> '') THEN BEGIN
            IF NOT Currency.GET(GenPosFunc."Secondary Total Currency") THEN
                CLEAR(Currency);
            SecTotal := ROUND(CurrencyExchRate.ExchangeAmtFCYToFCY(Transaction.Date, Transaction."Trans. Currency", Currency.Code,
                              Total), Currency."Amount Rounding Precision");
        END;
        IF (GenPosFunc."Print Disc/Cpn Info on Slip" =
            GenPosFunc."Print Disc/Cpn Info on Slip"::"Summary information below Sub-total") OR
           (GenPosFunc."Print Disc/Cpn Info on Slip" =
            GenPosFunc."Print Disc/Cpn Info on Slip"::"Detail for each line and Sub-total") OR
           (GenPosFunc."Print Disc/Cpn Info on Slip" =
            GenPosFunc."Print Disc/Cpn Info on Slip"::"Detail information for each line") THEN BEGIN
            PeriodicDiscountInfoTEMP.RESET;
            PeriodicDiscountInfoTEMP.SETCURRENTKEY(Status, Type);
            // Solo imprime descuentos de tipo tender type
            PeriodicDiscountInfoTEMP.SETRANGE("Offer Type", PeriodicDiscountInfoTEMP."Offer Type"::"Tender Type");
            NodeName[1] := 'Total Text';
            NodeName[2] := 'Total Amount';
            IF PeriodicDiscountInfoTEMP.FINDSET THEN BEGIN
                //Imprimir Linea en blanco...
                DSTR1 := COPYSTR('                     ', 1);
                Value[1] := '';
                PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                TotalAmtForSummary := Subtotal;
                REPEAT
                    IF (GenPosFunc."Print Disc/Cpn Info on Slip" =
                      GenPosFunc."Print Disc/Cpn Info on Slip"::"Detail for each line and Sub-total") AND
                      (PeriodicDiscountInfoTEMP.Description <> Text024) THEN
                        PeriodicDiscountInfoTEMP."Discount Amount Value" := 0;
                    IF PeriodicDiscountInfoTEMP."Discount Amount Value" <> 0 THEN BEGIN
                        DSTR1 := '#L################# #R##################';
                        Value[1] := PeriodicDiscountInfoTEMP.Description;
                        Value[2] := POSFunctions.FormatAmount(-PeriodicDiscountInfoTEMP."Discount Amount Value");
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        PrintUL.AddPrintLine(800, 2, NodeName, Value, DSTR1, FALSE, FALSE, FALSE, FALSE, Tray);
                        TotalAmtForSummary := TotalAmtForSummary + PeriodicDiscountInfoTEMP."Discount Amount Value";
                    END;
                    IF PeriodicDiscountInfoTEMP."Discount % Value" <> 0 THEN BEGIN   //Points
                        DSTR1 := '#L################# #R##################';
                        Value[1] := PeriodicDiscountInfoTEMP.Description;
                        Value[2] := POSFunctions.FormatAmount(PeriodicDiscountInfoTEMP."Discount % Value") + ' ' + Text232;
                        PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        PrintUL.AddPrintLine(800, 2, NodeName, Value, DSTR1, FALSE, FALSE, FALSE, FALSE, Tray);
                    END;
                UNTIL PeriodicDiscountInfoTEMP.NEXT = 0;

                IF TipsAmount1 <> 0 THEN BEGIN
                    DSTR1 := '#L################# #R##################';
                    Value[1] := TipsText1 + ' ' + Globals.GetValue('CURRSYM');
                    Value[2] := POSFunctions.FormatAmount(-TipsAmount1);
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    PrintUL.AddPrintLine(800, 2, NodeName, Value, DSTR1, FALSE, FALSE, FALSE, FALSE, Tray);
                END;
                IF TipsAmount2 <> 0 THEN BEGIN
                    DSTR1 := '#L################# #R##################';
                    Value[1] := TipsText2 + ' ' + Globals.GetValue('CURRSYM');
                    Value[2] := POSFunctions.FormatAmount(-TipsAmount2);
                    PrintUL.PrintLine(Tray, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    PrintUL.AddPrintLine(800, 2, NodeName, Value, DSTR1, FALSE, FALSE, FALSE, FALSE, Tray);
                END;
            END
            ELSE BEGIN
            END;
        END
        ELSE BEGIN
        END;
    end;

    procedure SaveRolloAuditor(FechaIni: Date; Zid: Code[20]; PTerminal: Code[10])
    var
        VZid: Code[20];
        Parameter: Record "FSN Parameter";
        StartStatus: Record "LSC POS Start Status";
        next: Boolean;
    begin
        Fecha := Today;
        next := false;
        PrintingCopyRollo.reset;
        PrintingCopyRollo.SETRANGE("Store No.", Globals.StoreNo);
        PrintingCopyRollo.SETRANGE("Pos Terminal No.", Globals.TerminalNo);
        PrintingCopyRollo.SETRANGE(Date, Fecha);

        CLEAR(AuditorRoll_lrep);
        AuditorRoll_lrep.USEREQUESTPAGE(false);
        AuditorRoll_lrep.SETTABLEVIEW(PrintingCopyRollo);
        Parameter.Reset;
        Parameter.SetRange(Grupo, 'POSROLLOA');
        Parameter.SetRange(Codigo, Globals.TerminalNo);
        IF Parameter.FindFirst THEN BEGIN
            IF COPYSTR(Parameter."Web Uri", STRLEN(Parameter."Web Uri")) <> '\' THEN
                Parameter."Web Uri" += '\';
            //AuditorRoll_lrep.SaveAsPdf('C:\Temp\Rollo.PDF');
            AuditorRoll_lrep.SaveAsPdf(Parameter."Web Uri" + 'RolloAuditorMH' + '-' +
            DELCHR(FORMAT(Fecha), '=', '/') + '-' + Globals.StoreNo + '-' + Globals.TerminalNo + '.PDF');

            if Zid <> '' then begin
                PaymEntry.Reset();
                PaymEntry.SETCURRENTKEY("Statement Code", "Z-Report ID", "Tender Type", "Currency Code", "Card No.");
                PaymEntry.SETRANGE("Statement Code", PTerminal);
                PaymEntry.SETRANGE("Z-Report ID", '');
                PaymEntry.SETRANGE("Currency Code");
                PaymEntry.SETRANGE("Card No.");
                PaymEntry.SETRANGE("Tender Type");
                IF PaymEntry.FIND('-') THEN
                    REPEAT
                        StartStatus.Reset();
                        StartStatus.SetCurrentKey("Store No.", Type, ID);
                        StartStatus.SetRange("Store No.", PaymEntry."Store No.");
                        StartStatus.SetRange(StartStatus.Type, StartStatus.Type::"POS Terminal");
                        StartStatus.SetRange(StartStatus.ID, PaymEntry."POS Terminal No.");
                        if StartStatus.FindSet() then begin
                            if PaymEntry."Tender Decl. ID" = StartStatus."Next Tender Decl. ID" then
                                next := true;
                        end;

                        PaymTrans2 := PaymEntry;
                        PaymTrans2."Z-Report ID" := Zid;
                        PaymTrans2.MODIFY(TRUE);
                    UNTIL PaymEntry.NEXT = 0;

                if next then begin
                    StartStatus.Reset();
                    StartStatus.SetCurrentKey("Store No.", Type, ID);
                    StartStatus.SetRange("Store No.", POSSESSION.StoreNo());
                    StartStatus.SetRange(StartStatus.Type, StartStatus.Type::"POS Terminal");
                    StartStatus.SetRange(StartStatus.ID, POSSESSION.TerminalNo());
                    if StartStatus.FindSet() then begin
                        StartStatus."Next Tender Decl. ID" := IncStr(StartStatus."Next Tender Decl. ID");
                        StartStatus.Modify();
                    end;
                end;

                CLEAR(TendDeclEntry);
                TendDeclEntry.SETCURRENTKEY("Statement Code", "Z-Report ID", "Tender Type", "Currency Code", "Card No.");
                TendDeclEntry.SETRANGE("Statement Code", PTerminal);
                TendDeclEntry.SETRANGE("Z-Report ID", '');
                IF TendDeclEntry.FIND('-') THEN
                    REPEAT
                        TendDeclEntry2 := TendDeclEntry;
                        TendDeclEntry2."Z-Report ID" := Zid;
                        TendDeclEntry2.MODIFY(TRUE);
                    UNTIL TendDeclEntry.NEXT = 0;

                CLEAR(IncExpEntry);
                IncExpEntry.SETCURRENTKEY("Statement Code", "Z-Report ID");
                IncExpEntry.SETRANGE("Statement Code", PTerminal);
                IncExpEntry.SETRANGE("Z-Report ID", '');
                IF IncExpEntry.FIND('-') THEN
                    REPEAT
                        IncExpEntry2 := IncExpEntry;
                        IncExpEntry2."Z-Report ID" := Zid;
                        IncExpEntry2.MODIFY(TRUE);
                    UNTIL IncExpEntry.NEXT = 0;

                Globals.SetValue('LAST_ZID', Zid);

                ZReportHist.INIT;
                ZReportHist."Store No." := Globals.StoreNo;
                ZReportHist."POS Terminal No." := Globals.TerminalNo;
                ZReportHist."Z-Report ID" := Zid;
                ZReportHist."Correlativo Fiscal" := NoCorrelativoXZ;
                ZReportHist.Fecha := TODAY;
                ZReportHist.Hora := TIME;
                ZReportHist.INSERT;

                ModifyHeaderIDZreport(Zid, PTerminal);

            end;

        END;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnButtonPressed', '', true, true)]
    local procedure "LSC POS Controller_OnButtonPressed"
(
    var POSMenuLine: Record "LSC POS Menu Line";
    var handled: Boolean
)
    var
        TransHeader: Record "LSC Transaction Header";
    begin
        if POSMenuLine.Command = 'LOGON' then begin
            TransHeader.Reset();
            TransHeader.SetRange(TransHeader."Entry Status", TransHeader."Entry Status"::Voided);
            TransHeader.SetRange(TransHeader."Z-Report ID", '');
            TransHeader.SetFilter(TransHeader.Date, '<%1', Today);
            if TransHeader.find('-') then begin
                repeat
                    TransHeader."Z-Report ID" := 'Z000000';
                    TransHeader.Modify(true);
                until TransHeader.Next() = 0;
            end;
        end;
    end;

    procedure ConvertCommandToType(Command: Text[50]): Text[10]
    begin
        CASE Command OF
            'BANCHECKINN':
                BEGIN
                END;
            'BANCHECKINNA':
                BEGIN
                END;
            'BANCHECKOUT':
                BEGIN
                END;
            'BANCHECKOUTA':
                BEGIN
                END;
            'BANCOMPRADEV',
            'BANCOMPRAMILA',
            'BANCOMPRANORA',
            'BANCOMPRAPLAA',
            'EMVCOMPRANORA',
            'EMVCOMPRAMILA',
            'EMVCOMPRAPLAA',
            'MANCOMPRAMILA',
            'MANCOMPRANORA',
            'MANCOMPRAPLAA':
                BEGIN
                    EXIT('DEVOL');
                END;
            'BANCONMILLA',
            'MANCONMILLA',
            'EMVCONMILLA':
                BEGIN
                    EXIT('CONMILLA');
                END;
            'BANCOMPRAMIL',
            'MANCOMPRAMIL',
            'EMVCOMPRAMIL':
                BEGIN
                    EXIT('PUNTOS');
                END;
            'BANCOMPRANOR',
            'EMVCOMPRANOR',
            'MANCOMPRANOR':
                BEGIN
                    EXIT('NORMAL');
                END;
            'BANCOMPRAPLA',
            'MANCOMPRAPLA',
            'EMVCOMPRAPLA':
                BEGIN
                    EXIT('PLAZOS');
                END;
            'EMVCHECKINN':
                BEGIN
                END;
            'EMVCHECKOUT':
                BEGIN
                END;
            'EMVCHECKOUTA':
                BEGIN
                END;
            'MANCHECKINN':
                BEGIN
                END;
            'MANCHECKOUT':
                BEGIN
                END;
            ELSE
                EXIT('NA');
        END;
    end;

    //////////////////////////////////////////Z_MENSUAL/////////////////////////////////////////////////////
    procedure PrintZReportMensual(DoCheck: Boolean)
    var
        TSErr: Text;
        TmpStaff: Record "LSC Staff";
        lStaffRec: Record "LSC Staff";
        NoSuspPOSTransactionsVoided: Integer;
        rFechaAuxiliar: Record "FSN Fecha Auxiliar";
        pFechaZMensual: Page "FSN Fecha ZMensual";
        Text177: Label 'Are you sure you want to print a Z Report Mensual?';
        Text172: Label 'Printing...';
        TSUtil: Codeunit "LSC POS Trans. Server Utility";
        Text223: Label 'Transaction server could not be contacted. Do you want to print for this terminal only?';
    begin

        //PrintZReport

        IF DoCheck THEN BEGIN
            IF NOT TestNewTransaction THEN
                EXIT;
        END;


        IF NOT PosConfirm(Text177, true) THEN
            EXIT;
        rFechaAuxiliar.RESET;
        IF rFechaAuxiliar.FINDSET THEN
            rFechaAuxiliar.DELETEALL;
        rFechaAuxiliar.INIT;
        rFechaAuxiliar.ID := 1;
        rFechaAuxiliar.VALIDATE(Mes, rFechaAuxiliar.Mes::" ");
        rFechaAuxiliar.VALIDATE(Anio, 0);
        rFechaAuxiliar.INSERT;
        COMMIT;
        rFechaAuxiliar.RESET;
        rFechaAuxiliar.FINDLAST;
        pFechaZMensual.SETTABLEVIEW(rFechaAuxiliar);
        pFechaZMensual.RUNMODAL;

        ScreenDisplay(Text172);
        IF TSUtil.GetStaff(TmpStaff, POSSESSION.StaffID, TSErr) THEN
            TmpStaff.MODIFY;

        TSErr := '';
        IF NOT TSUtil.ReadStatementTransactions(TRUE, TSErr) THEN BEGIN
            IF (TSErr <> '') THEN BEGIN
                IF NOT PosConfirm(Text223, FALSE) THEN
                    EXIT;
            END;
        END;

        IF PrintZReportMensualSV(true) THEN BEGIN
            COMMIT;

            IF lStaffRec.GET(POSSESSION.StaffID) THEN;
            IF TSUtil.UpdateStaff(lStaffRec) THEN;
            TSUtil.UpdateXZReportInformation(TRUE);
        END;
    end;

    procedure PosConfirm(Txt: Text[250]; YesDefault: Boolean): Boolean
    var
        Ok: Boolean;
        FunctionSetup: Record "LSC POS Command";
    begin
        //PosConfirm
        Ok := POSGUI.PosConfirm(Txt, YesDefault);
        exit(Ok);
    end;

    procedure ScreenDisplay(pText: Text[250])
    begin
        //ScreenDisplay
        POSGUI.ScreenDisplay(pText);
    end;

    procedure TestNewTransaction(): Boolean
    var
        PosTransLine3: Record "LSC POS Trans. Line";
        REC: Record "LSC POS Transaction";
        Text199: Label 'Current transaction must be finished!';
    begin
        //TestNewTransaction
        REC.Reset();
        if REC.Get(PosTransC.GetReceiptNo()) then
            IF NOT REC."New Transaction" THEN
                Message(Text199);
        EXIT(REC."New Transaction");
    end;

    procedure PrintZReportMensualSV(DoZ: Boolean): Boolean
    var
        Staff: Record "LSC Staff";
        Terminal: Record "LSC POS Terminal";
        SCode: Code[20];
        Transaction: Record "LSC Transaction Header";
        DSTR1: Text[80];
        rCompanyInfo: Record "Company Information";
        rNoSeries: Record "No. Series";
        rNoSeriesLn: Record "No. Series Line";
        Transaction2: Record "LSC Transaction Header";
        PaymTrans3: Record "LSC Trans. Payment Entry";
        RemoveTotal: Decimal;
        FloatTotal: Decimal;
        FirstTicket: Code[20];
        LastTicket: Code[20];
        Venta: Decimal;
        Iva: Decimal;
        vTotal: Decimal;
        rSalesEntry: Record "LSC Trans. Sales Entry";
        VentasG: Decimal;
        VentasE: Decimal;
        VentasNoSu: Decimal;
        TotalIva: Decimal;
        TotalVentNcr: Decimal;
        TotalIvaNcr: Decimal;
        VentasEDev: Decimal;
        VentasNoSuDev: Decimal;
        Percepcion: Decimal;
        Retencion: Decimal;
        PercepcionDev: Decimal;
        RetencionDev: Decimal;
        Percibido: Decimal;
        Retenido: Decimal;
        Correlativo: Integer;
        //TmpTender: Record "50004";
        rTenderTypeSetup: Record "LSC Tender Type Setup";
        rTransPaymentEntry: Record "LSC Trans. Payment Entry";
        VFondoFijo: Decimal;
        VRetiroEfectivo: Decimal;
        VEfectivoRetiro: Decimal;
        VTarjetaManualRetiro: Decimal;
        VTarjetaRetiro: Decimal;
        vChequeRetiro: Decimal;
        VCreditoRetiro: Decimal;
        VLealtadRetiro: Decimal;
        VTarjetaRegaloRetiro: Decimal;
        IncExpAccount: Record "LSC Income/Expense Account";
        IncExpEntry: Record "LSC Trans. Inc./Exp. Entry";
        PaymTemp: Record "LSC Trans. Payment Entry";
        RecCount: Integer;
        SuspTrans: Record "LSC POS Transaction";
        NoSuspended: Integer;
        NoSuspPrepayment: Integer;
        SuspPrepayment: Integer;
        SuspTransLine: Record "LSC POS Trans. Line";
        ZReportID: Code[10];
        TransServerWorkTable: Record "LSC Trans. Server Work Table";
        TransNotSent: Integer;
        PaymTrans2: Record "LSC Trans. Payment Entry";
        TendDeclEntry2: Record "LSC Trans. Tender Declar. Entr";
        IncExpEntry2: Record "LSC Trans. Inc./Exp. Entry";
        Transaction3: Record "LSC Transaction Header";
        NoCorrelativoXZ: Code[20];
        //ZReportHist: Record "50006";
        TextEncXMensual: Label 'XXXXXXXXX CORTE X PARCIAL XXXXXXXXX';
        TextEncZMensual: Label 'CORTE Z MENSUAL';
        TextNRC: Label 'NRC.';
        TextRNC: Label 'NIT';
        TextGIRO: Label 'GIRO';
        TextCodTienda: Label 'Cod.Tienda:';
        TextCaja: Label 'Caja:';
        rFecha: Record "Date";
        InicPeriodo: Date;
        FinPeriodo: Date;
        FirstFactCf: Code[30];
        LastFactCf: Code[30];
        FirstFactCrf: Code[30];
        LastFactCrf: Code[30];
        vVentasGravadasTotales: Decimal;
        vImpuestosTotales: Decimal;
        vTotalGravadoTotales: Decimal;
        vVentasExentasTotales: Decimal;
        vVentasNoSujetasTotales: Decimal;
        vVentasTotalesTotales: Decimal;
        vImpuestoIVATotales: Decimal;
        vIVAPercibidoTotales: Decimal;
        vIVAPercibidoDevTotales: Decimal;
        vIVARetenidoTotales: Decimal;
        vFirstFactCredAut: Text[30];
        vLastFactCredAut: Text[30];
        FirstFactCrfDev: Code[30];
        LastFactCrfDev: Code[30];
        FirstFactCfDev: Code[30];
        LastFactCfDev: Code[30];
        vTotalDocDevolucion: Decimal;
        vTotalIvaDocDevolucion: Decimal;
        vTotalRetencionDev: Decimal;
        VentasEDevDocDev: Decimal;
        vFirstFactCFAut: Text[30];
        vLastFactCFAut: Text[30];
        vNoDevoluciones: Integer;
        rFechaAuxiliar: Record "FSN Fecha Auxiliar";
        //rFechaAuxiliar: Record "No. Series Line" temporary;
        vMesNo: Integer;
        vFirstFechaCref: Date;
        vLastFechaCref: Date;
        vFirstFechaNocre: Date;
        vLastFechaNocre: Date;
        vFirstFechaFac: Date;
        vLastFechaFac: Date;
        vCESC: Decimal;
        vCESCTotales: Decimal;
        InputDate: Date;
    begin

        //PrintXZReport
        IF NOT Staff.GET(Globals.StaffID) THEN
            EXIT(TRUE);
        IF NOT Terminal.GET(Globals.TerminalNo) THEN
            EXIT(TRUE);
        IF NOT PrintUL.OpenReceiptPrinter(2, 'TENDER', 'ZXREPORTM', 0, '') THEN
            EXIT(FALSE);

        Store.GET(Globals.StoreNo());

        IF NOT Terminal."Terminal Statement" THEN
            Terminal."Statement Method" := Store."Statement Method";

        SCode := POSFunctions.GetStatementCode;

        Transaction.Date := TODAY;
        Transaction.Time := TIME;
        PrintUL.PrintSeperator(2);
        //ENCABEZADO....
        DSTR1 := '#C######################################';
        Value[1] := TextEncZMensual;
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        InputDate := Today;
        rFechaAuxiliar.RESET;
        rFechaAuxiliar.FINDLAST;
        DSTR1 := '#C######################################';
        Value[1] := 'Mes: ' + FORMAT(rFechaAuxiliar.Mes) + ' ' + FORMAT(rFechaAuxiliar.Anio);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        PrintUL.PrintSeperator(2);

        //información general
        DSTR1 := '#L######################################';
        Value[1] := 'Fecha: ' + FORMAT(TODAY, 0, '<Day,2>/<Month,2>/<Year4>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        DSTR1 := '#L######################################';
        Value[1] := 'Hora: ' + FORMAT(TIME(), 0, '<Hours12>:<Minutes,2> <AM/PM>');
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Nombre de la empresa...
        rCompanyInfo.GET();
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := rCompanyInfo.Name;
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Codigo Tipo Contribuyente y  No. Reg. Contribuyente de la empresa...
        rCompanyInfo.GET();
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := TextNRC + ':' + rCompanyInfo."FSN NRC";
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir NIT de la empresa...
        rCompanyInfo.GET();
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := TextRNC + ':' + rCompanyInfo."Federal ID No.";
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Giro de la empresa...
        rCompanyInfo.GET();
        DSTR1 := COPYSTR('#C#######################################', 1);
        Value[1] := TextGIRO + '::' + COPYSTR(rCompanyInfo."FSN NRC Description", 1, 26);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        DSTR1 := COPYSTR('#C#######################################', 1);
        Value[1] := COPYSTR(rCompanyInfo."FSN NRC Description", 26, 39);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir Nombre de la tienda.
        DSTR1 := COPYSTR('#L######################################', 1);
        Value[1] := Store.Name;
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir 1era. direccion de la tienda.
        DSTR1 := COPYSTR('#L######################################', 1);
        Value[1] := Store.Address;
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        //Imprimir 2da. direccion de la tienda.
        IF Store."Address 2" <> '' THEN BEGIN
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := Store."Address 2";
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;
        //Imprimir el No. de la Caja..
        DSTR1 := COPYSTR('#L################## #R#################', 1);
        Value[1] := TextCodTienda + ' ' + Store."No.";
        Value[2] := TextCaja + ' ' + Terminal."No.";
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        PrintUL.PrintSeperator(2);
        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := 'Corte Z Mensual No.: ' + INCSTR(Terminal."FSN Last Z-ReportM");
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        Value[1] := '';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        CASE rFechaAuxiliar.Mes OF
            rFechaAuxiliar.Mes::Enero:
                vMesNo := 1;
            rFechaAuxiliar.Mes::Febrero:
                vMesNo := 2;
            rFechaAuxiliar.Mes::Marzo:
                vMesNo := 3;
            rFechaAuxiliar.Mes::Abril:
                vMesNo := 4;
            rFechaAuxiliar.Mes::Mayo:
                vMesNo := 5;
            rFechaAuxiliar.Mes::Junio:
                vMesNo := 6;
            rFechaAuxiliar.Mes::Julio:
                vMesNo := 7;
            rFechaAuxiliar.Mes::Agosto:
                vMesNo := 8;
            rFechaAuxiliar.Mes::Septiembre:
                vMesNo := 9;
            rFechaAuxiliar.Mes::Octubre:
                vMesNo := 10;
            rFechaAuxiliar.Mes::Noviembre:
                vMesNo := 11;
            rFechaAuxiliar.Mes::Diciembre:
                vMesNo := 12;
        END;
        InicPeriodo := DMY2DATE(1, vMesNo, rFechaAuxiliar.Anio);
        IF vMesNo < 12 THEN
            FinPeriodo := CALCDATE('-1D', DMY2DATE(1, vMesNo + 1, rFechaAuxiliar.Anio))
        ELSE
            FinPeriodo := CALCDATE('-1D', DMY2DATE(1, 1, rFechaAuxiliar.Anio + 1));
        // para que se imprima la ultima fecha de las transacciones encontradas
        Transaction2.RESET;
        Transaction2.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
        Transaction2.SETRANGE(Transaction2."POS Terminal No.", Terminal."No.");
        Transaction2.SETRANGE("Statement Code", SCode);
        Transaction2.SETFILTER("Z-Report ID", '<>%1', '');
        Transaction2.SETRANGE("Transaction Type", Transaction."Transaction Type"::Sales);
        Transaction2.SETFILTER("Entry Status", '%1|%2', Transaction."Entry Status"::" ", Transaction."Entry Status"::Posted);
        Transaction2.SETRANGE(Date, InicPeriodo, FinPeriodo);

        IF Transaction2.FINDLAST THEN BEGIN
            DSTR1 := '#L################## #L#################';
            Value[1] := 'Del:' + FORMAT(InicPeriodo, 0, '<Day,2>/<Month,2>/<Year4>');
            Value[2] := 'Al:' + FORMAT(Transaction2.Date, 0, '<Day,2>/<Month,2>/<Year4>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;

        PrintUL.PrintSeperator(2);
        //Imprimir Linea en blanco...
        DSTR1 := COPYSTR('                     ', 1);
        Value[1] := '';
        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        IF GenPosFunc."TS Floating Cashier" AND
           (Terminal."Statement Method" = Terminal."Statement Method"::Staff) AND
           (Globals.GetValue('TS_ERROR') <> '') THEN BEGIN
        END;
        CLEAR(PaymEntry);
        PaymEntry.SETCURRENTKEY("Statement Code", "Z-Report ID", "Tender Type", "Currency Code", "Card No.");
        PaymEntry.SETRANGE("Statement Code", SCode);
        PaymEntry.SETRANGE("Z-Report ID", '');
        PaymTrans3.COPYFILTERS(PaymEntry);

        TenderType.SETCURRENTKEY("Store No.");
        TenderType.SETRANGE("Store No.", Globals.StoreNo);
        TenderType.SETFILTER(TenderType."Function", '<>%1', TenderType."Function"::"Tender Remove/Float");
        TenderType.SETRANGE("Foreign Currency", FALSE);
        LocalTotal := 0;
        TenderType.SETRANGE("Foreign Currency", TRUE);
        LocalTotal := 0;

        TenderType.SETRANGE("Foreign Currency");
        TenderType.SETRANGE(TenderType."Function", TenderType."Function"::"Tender Remove/Float");
        IF TenderType.FIND('-') THEN BEGIN
            REPEAT
                PaymEntry.SETRANGE("Currency Code");
                PaymEntry.SETRANGE("Card No.");
                PaymEntry.SETRANGE("Tender Type", TenderType.Code);
                IF PaymEntry.FIND('-') THEN
                    REPEAT
                        Transaction.GET(PaymEntry."Store No.", PaymEntry."POS Terminal No.", PaymEntry."Transaction No.");
                        CASE Transaction."Transaction Type" OF
                            Transaction."Transaction Type"::"Remove Tender":
                                RemoveTotal := RemoveTotal + PaymEntry."Amount Tendered";
                            Transaction."Transaction Type"::"Float Entry":
                                FloatTotal := FloatTotal + PaymEntry."Amount Tendered";
                        END;
                    UNTIL PaymEntry.NEXT = 0;
            UNTIL TenderType.NEXT = 0;
        END;

        Transaction."Transaction No." := 0;
        TendDeclEntry.SETCURRENTKEY("Statement Code", "Z-Report ID", "Tender Type", "Currency Code", "Card No.");
        TendDeclEntry.SETRANGE("Statement Code", SCode);
        TendDeclEntry.SETRANGE("Z-Report ID", '');
        IF Store."Tend. Decl. Calculation" = Store."Tend. Decl. Calculation"::Sum THEN BEGIN
            BufferTendDeclEntry;
            IF TendDeclEntry.FIND('-') THEN
                Transaction."Transaction No." := TendDeclEntry."Transaction No.";
        END ELSE BEGIN
            IF TendDeclEntry.FIND('-') THEN
                REPEAT
                    IF TendDeclEntry."Transaction No." > Transaction."Transaction No." THEN
                        Transaction.GET(TendDeclEntry."Store No.", TendDeclEntry."POS Terminal No.", TendDeclEntry."Transaction No.")
                UNTIL TendDeclEntry.NEXT = 0;
        END;

        IF Transaction."Transaction No." <> 0 THEN BEGIN
            CLEAR(TendDeclEntry);
            LocalTotal := 0;
            IF Store."Tend. Decl. Calculation" = Store."Tend. Decl. Calculation"::Last THEN BEGIN
                TendDeclEntry.SETCURRENTKEY("Store No.", "POS Terminal No.", "Transaction No.");
                TendDeclEntry.SETRANGE("Store No.", Transaction."Store No.");
                TendDeclEntry.SETRANGE("POS Terminal No.", Transaction."POS Terminal No.");
                TendDeclEntry.SETRANGE("Transaction No.", Transaction."Transaction No.");
                BufferTendDeclEntry;
            END;
            TempTendDeclEntry.SETFILTER("Currency Code", '=%1', '');
            Transaction."Gross Amount" := -LocalTotal;
            TempTendDeclEntry.SETFILTER("Currency Code", '<>%1', '');
        END;

        //BUSCO LOS TICKETS Y LAS DEVOLUCIONES PARA EL REPORTE X...
        IF DoZ THEN BEGIN
            vVentasGravadasTotales := 0;
            vImpuestoIVATotales := 0;
            vTotalGravadoTotales := 0;
            vVentasExentasTotales := 0;
            vVentasNoSujetasTotales := 0;
            vVentasTotalesTotales := 0;
            vIVAPercibidoTotales := 0;
            vIVAPercibidoDevTotales := 0;
            vIVARetenidoTotales := 0;

            //ENCABEZADO PARA EL TIPO DE COMPROBANTE
            DSTR1 := COPYSTR('#C######################################', 1);
            Value[1] := '1- Ticket';
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

            Transaction2.RESET;
            Transaction2.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
            Transaction2.SETRANGE(Transaction2."POS Terminal No.", Terminal."No.");
            Transaction2.SETRANGE("Statement Code", SCode);
            Transaction2.SETFILTER("Z-Report ID", '<>%1', '');
            Transaction2.SETRANGE("Transaction Type", Transaction2."Transaction Type"::Sales);
            Transaction2.SETFILTER("Entry Status", '%1|%2|%3', Transaction2."Entry Status"::" ", Transaction2."Entry Status"::Posted, Transaction2."Entry Status"::Voided);
            Transaction2.SETRANGE(Date, InicPeriodo, FinPeriodo);
            Transaction2.SETRANGE("FSN No. Serie NCF", Terminal."FSN No. Serie NCF Ticket");
            IF Transaction2.FINDFIRST THEN BEGIN
                rNoSeries.RESET;
                IF rNoSeries.GET(Terminal."FSN No. Serie NCF Ticket") THEN BEGIN
                    rNoSeriesLn.RESET;
                    rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
                    IF rNoSeriesLn.FINDFIRST THEN BEGIN
                        DSTR1 := COPYSTR('#L######################################', 1);
                        Value[1] := 'Autorizacion: ' + UPPERCASE(rNoSeriesLn."FSN Autorization");
                        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        //Imprimir el rango de ticket..
                        DSTR1 := COPYSTR('#L######################################', 1);
                        Value[1] := 'Del ' + rNoSeriesLn."Starting No.";
                        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        DSTR1 := COPYSTR('#L######################################', 1);
                        Value[1] := 'al  ' + rNoSeriesLn."Ending No.";
                        PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END;
                END;

                FirstTicket := Transaction2."FSN NCF";

                REPEAT
                    CLEAR(Venta);
                    CLEAR(Iva);
                    CLEAR(vTotal);
                    rSalesEntry.SETRANGE("Store No.", Transaction2."Store No.");
                    rSalesEntry.SETRANGE("POS Terminal No.", Transaction2."POS Terminal No.");
                    rSalesEntry.SETRANGE("Transaction No.", Transaction2."Transaction No.");
                    IF rSalesEntry.FIND('-') THEN
                        REPEAT
                            Venta += ABS(rSalesEntry."Net Amount");
                            Iva += ABS(rSalesEntry."VAT Amount");
                            vTotal += ABS(rSalesEntry."Net Amount") + ABS(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += ABS(rSalesEntry."Net Amount");
                                    TotalIva += ABS(rSalesEntry."VAT Amount");
                                END
                                ELSE BEGIN
                                    TotalVentNcr += ABS(rSalesEntry."Net Amount");
                                    TotalIvaNcr += ABS(rSalesEntry."VAT Amount");
                                END;
                            END
                            ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += ABS(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += ABS(rSalesEntry."Net Amount")
                                END;
                            END;
                        UNTIL rSalesEntry.NEXT = 0;
                    LastTicket := Transaction2."FSN NCF";
                UNTIL Transaction2.NEXT = 0;
            END;

            IF (FirstTicket <> '') OR (LastTicket <> '') THEN BEGIN
                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := 'Del No.: ' + FirstTicket;
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := 'Al No.: ' + LastTicket;
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END;
            //Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            Value[1] := '';
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            VentasG := VentasG - TotalVentNcr;

            //VENTAS GRAVADAS...
            DSTR1 := COPYSTR('#L##############    #R##################', 1);
            Value[1] := 'Ventas Gravadas:';
            Value[2] := '$' + FORMAT(VentasG, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            TotalIva := TotalIva - TotalIvaNcr;
            //IMPUESTO IVA...
            DSTR1 := COPYSTR('#L###########       #R##################', 1);
            Value[1] := 'Impuesto IVA:';
            Value[2] := '$' + FORMAT(TotalIva - vCESC, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //IMPUESTO CESC...
            DSTR1 := COPYSTR('#L############           #R#############', 1);
            Value[1] := 'Impuesto CESC:';
            Value[2] := '$' + FORMAT(vCESC, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Total Gravado...
            DSTR1 := COPYSTR('#L############      #R##################', 1);
            Value[1] := 'Total Gravado:';
            Value[2] := '$' + FORMAT(VentasG + TotalIva, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //VENTAS EXENTAS...
            DSTR1 := COPYSTR('#L#############     #R##################', 1);
            Value[1] := 'Ventas Exentas:';
            Value[2] := '$' + FORMAT((VentasE - VentasEDev), 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //VENTAS NO SUJETAS...
            DSTR1 := COPYSTR('#L################  #R##################', 1);
            Value[1] := 'Ventas No Sujetas:';
            Value[2] := '$' + FORMAT((VentasNoSu - VentasNoSuDev), 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //VENTAS TOTALES
            DSTR1 := COPYSTR('#L#############     #R##################', 1);
            Value[1] := 'Ventas Totales:';
            Value[2] := '$' + FORMAT((VentasG + TotalIva + VentasE + VentasNoSu) - (VentasEDev + VentasNoSuDev), 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            vVentasGravadasTotales := vVentasGravadasTotales + VentasG;
            vImpuestoIVATotales := vImpuestoIVATotales + TotalIva - vCESC;
            vCESCTotales := vCESCTotales + vCESC;
            vTotalGravadoTotales := vTotalGravadoTotales + (VentasG + TotalIva);
            vVentasExentasTotales := vVentasExentasTotales + (VentasE - VentasEDev);
            vVentasNoSujetasTotales := vVentasNoSujetasTotales + (VentasNoSu - VentasNoSuDev);
            vVentasTotalesTotales := vVentasTotalesTotales + ((VentasG + TotalIva + VentasE + VentasNoSu) - (VentasEDev + VentasNoSuDev));

            //LIMPIO LAS VARIABLES QUE MUESTRAN LOS TOTALES DE LAS VENTAS POR TIPO DE COMPROBANTES.
            CLEAR(FirstTicket);
            CLEAR(LastTicket);
            CLEAR(Venta);
            CLEAR(Iva);
            CLEAR(vTotal);
            CLEAR(VentasG);
            CLEAR(TotalIva);
            CLEAR(TotalVentNcr);
            CLEAR(TotalIvaNcr);
            CLEAR(VentasE);
            CLEAR(VentasNoSu);
            CLEAR(VentasEDev);
            CLEAR(VentasNoSuDev);
            CLEAR(vCESC);

            //Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            Value[1] := '';
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //ENCABEZADO PARA EL TIPO DE COMPROBANTE
            DSTR1 := COPYSTR('#C######################################', 1);
            Value[1] := '2- Comprobante de Crédito Fiscal';
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

            //BUSCO PRIMERO LOS NCF PARA CREDITO FISCALES
            Transaction2.RESET;
            Transaction2.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
            Transaction2.SETRANGE(Transaction2."POS Terminal No.", Terminal."No.");
            Transaction2.SETRANGE("Statement Code", SCode);
            Transaction2.SETFILTER("Z-Report ID", '<>%1', '');
            Transaction2.SETRANGE("Transaction Type", Transaction2."Transaction Type"::Sales);
            Transaction2.SETFILTER("Entry Status", '%1|%2|%3', Transaction2."Entry Status"::" ", Transaction2."Entry Status"::Posted, Transaction2."Entry Status"::Voided);
            Transaction2.SETRANGE("FSN No. Serie NCF", Terminal."FSN No. Serie Credito Fiscal");
            Transaction2.SETRANGE(Date, InicPeriodo, FinPeriodo);
            IF Transaction2.FINDFIRST THEN BEGIN

                rNoSeries.RESET;
                IF rNoSeries.GET(Terminal."FSN No. Serie Credito Fiscal") THEN BEGIN
                    rNoSeriesLn.RESET;
                    rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
                    IF rNoSeriesLn.FINDFIRST THEN BEGIN
                        DSTR1 := COPYSTR('#L######################################', 1);
                        Value[1] := 'Autorizacion: ' + UPPERCASE(rNoSeriesLn."FSN Autorization");
                        DSTR1 := COPYSTR('#L#################  #R#################', 1);
                        Value[1] := 'Del ' + rNoSeriesLn."Starting No.";
                        Value[2] := 'al  ' + rNoSeriesLn."Ending No.";
                    END;
                END;
                FirstFactCrf := Transaction2."FSN NCF";
                vFirstFechaCref := Transaction2.Date;
                REPEAT
                    CLEAR(Venta);
                    CLEAR(Iva);
                    CLEAR(vTotal);
                    rSalesEntry.SETRANGE("Store No.", Transaction2."Store No.");
                    rSalesEntry.SETRANGE("POS Terminal No.", Transaction2."POS Terminal No.");
                    rSalesEntry.SETRANGE("Transaction No.", Transaction2."Transaction No.");
                    IF rSalesEntry.FIND('-') THEN
                        REPEAT
                            Venta += ABS(rSalesEntry."Net Amount");
                            Iva += ABS(rSalesEntry."VAT Amount");
                            vTotal += ABS(rSalesEntry."Net Amount") + ABS(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += ABS(rSalesEntry."Net Amount");
                                    TotalIva += ABS(rSalesEntry."VAT Amount");
                                END
                                ELSE BEGIN
                                    TotalVentNcr += ABS(rSalesEntry."Net Amount");
                                    TotalIvaNcr += ABS(rSalesEntry."VAT Amount");
                                END;
                            END
                            ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += ABS(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += ABS(rSalesEntry."Net Amount")
                                END;
                            END;
                        UNTIL rSalesEntry.NEXT = 0;
                    //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                    //se agrego rango de facturas
                    LastFactCrf := Transaction2."FSN Correlative";
                    vLastFechaCref := Transaction2.Date;
                    //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                    IF NOT Transaction2."Sale Is Return Sale" THEN
                        Percepcion += ABS(Transaction2."FSN Perception Amount")
                    ELSE
                        PercepcionDev += -(Transaction2."FSN Perception Amount");
                UNTIL Transaction2.NEXT = 0;
            END;
            //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
            //se agrego rango de facturas
            IF (FirstFactCrf <> '') OR (LastFactCrf <> '') THEN BEGIN
                rNoSeriesLn.RESET;
                rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
                IF rNoSeriesLn.FINDFIRST THEN
                    REPEAT
                        IF ((rNoSeriesLn."Starting No." <= FirstFactCrf) AND (rNoSeriesLn."Ending No." >= FirstFactCrf)) AND
                        ((rNoSeriesLn."Starting Date" <= vFirstFechaCref) AND (rNoSeriesLn."Last Date Used" >= vFirstFechaCref)) THEN
                            vFirstFactCredAut := UPPERCASE(rNoSeriesLn.Series);
                        IF ((rNoSeriesLn."Starting No." <= LastFactCrf) AND (rNoSeriesLn."Ending No." >= LastFactCrf)) AND
                        ((rNoSeriesLn."Starting Date" <= vLastFechaCref) AND (rNoSeriesLn."Last Date Used" >= vLastFechaCref)) THEN
                            vLastFactCredAut := UPPERCASE(rNoSeriesLn.Series);
                    UNTIL rNoSeriesLn.NEXT = 0;
                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := 'Del No.: ' + vFirstFactCredAut + ' ' + FirstFactCrf;
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := 'Al No.: ' + vLastFactCredAut + ' ' + LastFactCrf;
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END;

            //Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            Value[1] := '';
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            VentasG := VentasG - TotalVentNcr;

            //VENTAS GRAVADAS...
            DSTR1 := COPYSTR('#L##############    #R##################', 1);
            Value[1] := 'Ventas Gravadas:';
            Value[2] := '$' + FORMAT(VentasG, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            TotalIva := TotalIva - TotalIvaNcr;

            //IMPUESTO IVA...
            DSTR1 := COPYSTR('#L###########       #R##################', 1);
            Value[1] := 'Impuesto IVA:';
            Value[2] := '$' + FORMAT(TotalIva - vCESC, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //IMPUESTO CESC...
            DSTR1 := COPYSTR('#L############           #R#############', 1);
            Value[1] := 'Impuesto CESC:';
            Value[2] := '$' + FORMAT(vCESC, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Total Gravado...
            DSTR1 := COPYSTR('#L############      #R##################', 1);
            Value[1] := 'Total Gravado:';
            Value[2] := '$' + FORMAT(VentasG + TotalIva, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            CLEAR(Percibido);
            //PERCEPCION...
            DSTR1 := COPYSTR('#L################# #R##################', 1);
            Value[1] := '(+) IVA Percibido:';
            Value[2] := '$' + FORMAT((Percepcion), 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //VENTAS EXENTAS...
            DSTR1 := COPYSTR('#L#############     #R##################', 1);
            Value[1] := 'Ventas Exentas:';
            Value[2] := '$' + FORMAT((VentasE), 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //VENTAS NO SUJETAS...
            DSTR1 := COPYSTR('#L################  #R##################', 1);
            Value[1] := 'Ventas No Sujetas:';
            Value[2] := '$' + FORMAT((VentasNoSu), 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //VENTAS TOTALES
            DSTR1 := COPYSTR('#L#############     #R##################', 1);
            Value[1] := 'Ventas Totales:';
            Value[2] := '$' + FORMAT((VentasG + TotalIva + VentasE + VentasNoSu + Percepcion), 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            vVentasGravadasTotales := vVentasGravadasTotales + VentasG;
            vImpuestoIVATotales := vImpuestoIVATotales + TotalIva - vCESC;
            vCESCTotales := vCESCTotales + vCESC;
            vTotalGravadoTotales := vTotalGravadoTotales + (VentasG + TotalIva);
            vVentasExentasTotales := vVentasExentasTotales + (VentasE - VentasEDev);
            vVentasNoSujetasTotales := vVentasNoSujetasTotales + (VentasNoSu - VentasNoSuDev);
            vVentasTotalesTotales := vVentasTotalesTotales + ((VentasG + TotalIva + VentasE + VentasNoSu + (Percepcion - PercepcionDev)) - (VentasEDev + VentasNoSuDev));
            vIVAPercibidoTotales := vIVAPercibidoTotales + (Percepcion);

            //LIMPIO LAS VARIABLES QUE MUESTRAN LOS TOTALES DE LAS VENTAS POR TIPO DE COMPROBANTES.
            CLEAR(Venta);
            CLEAR(Iva);
            CLEAR(vTotal);
            CLEAR(VentasG);
            CLEAR(TotalIva);
            CLEAR(TotalVentNcr);
            CLEAR(TotalIvaNcr);
            CLEAR(VentasE);
            CLEAR(VentasNoSu);
            CLEAR(VentasEDev);
            CLEAR(VentasNoSuDev);
            CLEAR(Retencion);
            CLEAR(Percepcion);
            CLEAR(vCESC);

            //Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            Value[1] := '';
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Se agrego nota de credito y documento devolucion
            //ENCABEZADO PARA EL TIPO DE COMPROBANTE
            DSTR1 := COPYSTR('#C######################################', 1);
            Value[1] := '3- Nota de Crédito';
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

            //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
            //se agrego rango de facturas
            Transaction2.RESET;
            Transaction2.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
            Transaction2.SETRANGE(Transaction2."POS Terminal No.", Terminal."No.");
            Transaction2.SETRANGE("Statement Code", SCode);
            Transaction2.SETFILTER("Z-Report ID", '<>%1', '');
            Transaction2.SETRANGE("Transaction Type", Transaction2."Transaction Type"::Sales);
            Transaction2.SETFILTER("Entry Status", '%1|%2|%3', Transaction2."Entry Status"::" ", Transaction2."Entry Status"::Posted, Transaction2."Entry Status"::Voided);
            Transaction2.SETRANGE("FSN No. Serie NCF", Terminal."FSN No. Serie Nota de Credito");
            Transaction2.SETRANGE(Date, InicPeriodo, FinPeriodo);
            IF Transaction2.FINDFIRST THEN BEGIN
                rNoSeries.RESET;
                IF rNoSeries.GET(Terminal."FSN No. Serie Nota de Credito") THEN BEGIN
                    rNoSeriesLn.RESET;
                    rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
                    IF rNoSeriesLn.FINDFIRST THEN BEGIN
                        DSTR1 := COPYSTR('#L######################################', 1);
                        Value[1] := 'Autorizacion: ' + UPPERCASE(rNoSeriesLn."FSN Autorization");
                        DSTR1 := COPYSTR('#L#################  #R#################', 1);
                        Value[1] := 'Del ' + rNoSeriesLn."Starting No.";
                        Value[2] := 'al  ' + rNoSeriesLn."Ending No.";
                    END;
                END;
                //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                //se agrego rango de facturas
                FirstFactCrfDev := Transaction2."FSN NCF";
                vFirstFechaNocre := Transaction2.Date;
                //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda

                REPEAT
                    CLEAR(Venta);
                    CLEAR(Iva);
                    CLEAR(vTotal);
                    rSalesEntry.SETRANGE("Store No.", Transaction2."Store No.");
                    rSalesEntry.SETRANGE("POS Terminal No.", Transaction2."POS Terminal No.");
                    rSalesEntry.SETRANGE("Transaction No.", Transaction2."Transaction No.");
                    IF rSalesEntry.FIND('-') THEN
                        REPEAT
                            Venta += ABS(rSalesEntry."Net Amount");
                            Iva += ABS(rSalesEntry."VAT Amount");
                            vTotal += ABS(rSalesEntry."Net Amount") + ABS(rSalesEntry."VAT Amount");
                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += ABS(rSalesEntry."Net Amount");
                                    TotalIva += ABS(rSalesEntry."VAT Amount");
                                END
                                ELSE BEGIN
                                    TotalVentNcr += ABS(rSalesEntry."Net Amount");
                                    TotalIvaNcr += ABS(rSalesEntry."VAT Amount");
                                END;
                            END
                            ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += ABS(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += ABS(rSalesEntry."Net Amount")
                                END;
                            END;
                        UNTIL rSalesEntry.NEXT = 0;
                    //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                    //se agrego rango de facturas
                    LastFactCrfDev := Transaction2."FSN NCF";
                    vLastFechaNocre := Transaction2.Date;
                    //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                    IF NOT Transaction2."Sale Is Return Sale" THEN
                        Percepcion += ABS(Transaction2."FSN Perception Amount")
                    ELSE
                        PercepcionDev += -(Transaction2."FSN Perception Amount");
                UNTIL Transaction2.NEXT = 0;
            END;

            //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
            //se agrego rango de facturas
            IF (FirstFactCrfDev <> '') OR (LastFactCrfDev <> '') THEN BEGIN
                rNoSeriesLn.RESET;
                rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
                IF rNoSeriesLn.FINDFIRST THEN
                    REPEAT
                        IF ((rNoSeriesLn."Starting No." <= FirstFactCrfDev) AND (rNoSeriesLn."Ending No." >= FirstFactCrfDev)) AND
                        ((rNoSeriesLn."Starting Date" <= vFirstFechaNocre) AND (rNoSeriesLn."Last Date Used" >= vFirstFechaNocre)) THEN
                            vFirstFactCredAut := UPPERCASE(rNoSeriesLn.Series);
                        IF ((rNoSeriesLn."Starting No." <= LastFactCrfDev) AND (rNoSeriesLn."Ending No." >= LastFactCrfDev)) AND
                        ((rNoSeriesLn."Starting Date" <= vLastFechaNocre) AND (rNoSeriesLn."Last Date Used" >= vLastFechaNocre)) THEN
                            vLastFactCredAut := UPPERCASE(rNoSeriesLn.Series);
                    UNTIL rNoSeriesLn.NEXT = 0;
                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := 'Del No.: ' + vFirstFactCredAut + ' ' + FirstFactCrfDev;
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := 'Al No.: ' + vLastFactCredAut + ' ' + LastFactCrfDev;
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END;
            //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
            //Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            VentasG := VentasG - TotalVentNcr;
            //VENTAS GRAVADAS...
            DSTR1 := COPYSTR('#L##############    #R##################', 1);
            Value[1] := 'Ventas Gravadas:';
            Value[2] := '$' + FORMAT(VentasG, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            TotalIva := TotalIva - TotalIvaNcr;
            //IMPUESTO IVA...
            DSTR1 := COPYSTR('#L###########       #R##################', 1);
            Value[1] := 'Impuesto IVA:';
            Value[2] := '$' + FORMAT(TotalIva, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            //Total Gravado...
            DSTR1 := COPYSTR('#L############      #R##################', 1);
            Value[1] := 'Total Gravado:';
            Value[2] := '$' + FORMAT(VentasG + TotalIva, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            CLEAR(Percibido);
            //PERCEPCION...
            DSTR1 := COPYSTR('#L################# #R##################', 1);
            Value[1] := '(+) IVA Percibido:';
            Value[2] := '$' + FORMAT((-PercepcionDev), 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            //VENTAS EXENTAS...
            DSTR1 := COPYSTR('#L#############     #R##################', 1);
            Value[1] := 'Ventas Exentas:';
            Value[2] := '$' + FORMAT((VentasE - VentasEDev), 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            //VENTAS NO SUJETAS...
            DSTR1 := COPYSTR('#L################  #R##################', 1);
            Value[1] := 'Ventas No Sujetas:';
            Value[2] := '$' + FORMAT((VentasNoSu - VentasNoSuDev), 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            //VENTAS TOTALES
            DSTR1 := COPYSTR('#L#############     #R##################', 1);
            Value[1] := 'Ventas Totales:';
            Value[2] := '$' + FORMAT((VentasG + TotalIva + VentasE + VentasNoSu + (PercepcionDev + Percepcion)) - (VentasEDev + VentasNoSuDev), 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            vVentasGravadasTotales := vVentasGravadasTotales + VentasG;
            vImpuestoIVATotales := vImpuestoIVATotales + TotalIva;
            vTotalGravadoTotales := vTotalGravadoTotales + (VentasG + TotalIva);
            vVentasExentasTotales := vVentasExentasTotales + (VentasE - VentasEDev);
            vVentasNoSujetasTotales := vVentasNoSujetasTotales + (VentasNoSu - VentasNoSuDev);
            vVentasTotalesTotales := vVentasTotalesTotales + ((VentasG + TotalIva + VentasE + VentasNoSu + (PercepcionDev + Percepcion)) - (VentasEDev + VentasNoSuDev));
            vIVAPercibidoDevTotales := vIVAPercibidoDevTotales + (-PercepcionDev);
            //LIMPIO LAS VARIABLES QUE MUESTRAN LOS TOTALES DE LAS VENTAS POR TIPO DE COMPROBANTES.
            CLEAR(Venta);
            CLEAR(Iva);
            CLEAR(vTotal);
            CLEAR(VentasG);
            CLEAR(TotalIva);
            CLEAR(TotalVentNcr);
            CLEAR(TotalIvaNcr);
            CLEAR(VentasE);
            CLEAR(VentasNoSu);
            CLEAR(VentasEDev);
            CLEAR(VentasNoSuDev);
            CLEAR(Retencion);
            //Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Solo aparece el valor total de documentos de devolución en detalle de factura de consumidor final
            //ENCABEZADO PARA EL TIPO DE COMPROBANTE
            //BUSCO PRIMERO LOS NCF PARA FACTURAS DE CONSUMIDORES FINALES
            Transaction2.RESET;
            Transaction2.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
            Transaction2.SETRANGE(Transaction2."POS Terminal No.", Terminal."No.");
            Transaction2.SETRANGE("Statement Code", SCode);
            Transaction2.SETFILTER("Z-Report ID", '<>%1', '');
            Transaction2.SETRANGE("Transaction Type", Transaction2."Transaction Type"::Sales);
            Transaction2.SETFILTER("Entry Status", '%1|%2', Transaction2."Entry Status"::" ", Transaction2."Entry Status"::Posted);
            Transaction2.SETRANGE("FSN No. Serie NCF", Terminal."FSN No. Serie Devolucion");
            Transaction2.SETRANGE(Date, InicPeriodo, FinPeriodo);
            IF Transaction2.FINDFIRST THEN BEGIN
                //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                //se agrego rango de facturas
                FirstFactCfDev := Transaction2."FSN NCF";
                REPEAT
                    CLEAR(Venta);
                    CLEAR(Iva);
                    CLEAR(vTotal);
                    rSalesEntry.SETRANGE("Store No.", Transaction2."Store No.");
                    rSalesEntry.SETRANGE("POS Terminal No.", Transaction2."POS Terminal No.");
                    rSalesEntry.SETRANGE("Transaction No.", Transaction2."Transaction No.");
                    IF rSalesEntry.FIND('-') THEN
                        REPEAT
                            Venta += ABS(rSalesEntry."Net Amount");
                            Iva += ABS(rSalesEntry."VAT Amount");
                            vTotal += ABS(rSalesEntry."Net Amount") + ABS(rSalesEntry."VAT Amount");
                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += ABS(rSalesEntry."Net Amount");
                                    TotalIva += ABS(rSalesEntry."VAT Amount");
                                END
                                ELSE BEGIN
                                    TotalVentNcr += ABS(rSalesEntry."Net Amount");
                                    TotalIvaNcr += ABS(rSalesEntry."VAT Amount");
                                END;
                            END
                            ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += ABS(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += ABS(rSalesEntry."Net Amount")
                                END;
                            END;
                        UNTIL rSalesEntry.NEXT = 0;

                    //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                    //se agrego rango de facturas
                    LastFactCfDev := Transaction2."FSN NCF";
                    IF NOT Transaction2."Sale Is Return Sale" THEN
                        Retencion += ABS(Transaction2."FSN Retention Amount")
                    ELSE
                        RetencionDev += -(Transaction2."FSN Retention Amount");

                UNTIL Transaction2.NEXT = 0;
            END;

            //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
            //se agrego rango de facturas
            VentasG := VentasG - TotalVentNcr;
            TotalIva := TotalIva - TotalIvaNcr;
            //TOTAL documentos devolucion
            vTotalDocDevolucion := (VentasG + VentasE + VentasNoSu) - (VentasEDev + VentasNoSuDev);
            vTotalIvaDocDevolucion := TotalIva;
            vTotalRetencionDev := RetencionDev;

            VentasEDevDocDev := VentasEDev;
            vVentasExentasTotales := vVentasExentasTotales + (VentasE - VentasEDev);

            //LIMPIO LAS VARIABLES QUE MUESTRAN LOS TOTALES DE LAS VENTAS POR TIPO DE COMPROBANTES.
            CLEAR(Venta);
            CLEAR(Iva);
            CLEAR(vTotal);
            CLEAR(VentasG);
            CLEAR(TotalIva);
            CLEAR(TotalVentNcr);
            CLEAR(TotalIvaNcr);
            CLEAR(VentasE);
            CLEAR(VentasNoSu);
            CLEAR(VentasEDev);
            CLEAR(VentasNoSuDev);

            //ENCABEZADO PARA EL TIPO DE COMPROBANTE
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := '4- Factura Consumidor Final';
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

            //BUSCO PRIMERO LOS NCF PARA FACTURAS DE CONSUMIDORES FINALES
            Transaction2.RESET;
            Transaction2.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
            Transaction2.SETRANGE(Transaction2."POS Terminal No.", Terminal."No.");
            Transaction2.SETRANGE("Statement Code", SCode);
            Transaction2.SETFILTER("Z-Report ID", '<>%1', '');
            Transaction2.SETRANGE("Transaction Type", Transaction2."Transaction Type"::Sales);
            Transaction2.SETFILTER("Entry Status", '%1|%2|%3', Transaction2."Entry Status"::" ", Transaction2."Entry Status"::Posted, Transaction2."Entry Status"::Voided);
            Transaction2.SETRANGE("FSN No. Serie NCF", Terminal."FSN No. Serie NCF Cons. Final");
            Transaction2.SETRANGE(Date, InicPeriodo, FinPeriodo);
            IF Transaction2.FINDFIRST THEN BEGIN
                rNoSeries.RESET;
                IF rNoSeries.GET(Terminal."FSN No. Serie NCF Cons. Final") THEN BEGIN
                    rNoSeriesLn.RESET;
                    rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
                    IF rNoSeriesLn.FINDFIRST THEN BEGIN
                        DSTR1 := COPYSTR('#L######################################', 1);
                        Value[1] := 'Autorizacion: ' + UPPERCASE(rNoSeriesLn."FSN Autorization");

                        DSTR1 := COPYSTR('#L#################  #R#################', 1);
                        Value[1] := 'Del ' + rNoSeriesLn."Starting No.";
                        Value[2] := 'al  ' + rNoSeriesLn."Ending No.";
                    END;
                END;

                //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                //se agrego rango de facturas
                FirstFactCf := Transaction2."FSN Correlative";
                vFirstFechaFac := Transaction2.Date;
                REPEAT
                    CLEAR(Venta);
                    CLEAR(Iva);
                    CLEAR(vTotal);
                    rSalesEntry.SETRANGE("Store No.", Transaction2."Store No.");
                    rSalesEntry.SETRANGE("POS Terminal No.", Transaction2."POS Terminal No.");
                    rSalesEntry.SETRANGE("Transaction No.", Transaction2."Transaction No.");
                    IF rSalesEntry.FIND('-') THEN
                        REPEAT
                            Venta += ABS(rSalesEntry."Net Amount");
                            Iva += ABS(rSalesEntry."VAT Amount");
                            vTotal += ABS(rSalesEntry."Net Amount") + ABS(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += ABS(rSalesEntry."Net Amount");
                                    TotalIva += ABS(rSalesEntry."VAT Amount");
                                END
                                ELSE BEGIN
                                    TotalVentNcr += ABS(rSalesEntry."Net Amount");
                                    TotalIvaNcr += ABS(rSalesEntry."VAT Amount");
                                END;
                            END
                            ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += ABS(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += ABS(rSalesEntry."Net Amount")
                                END;
                            END;
                        UNTIL rSalesEntry.NEXT = 0;

                    //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
                    LastFactCf := Transaction2."FSN Correlative";
                    vLastFechaFac := Transaction2.Date;
                    IF NOT Transaction2."Sale Is Return Sale" THEN
                        Retencion += ABS(Transaction2."FSN Retention Amount")
                    ELSE
                        RetencionDev += -(Transaction2."FSN Retention Amount");
                UNTIL Transaction2.NEXT = 0;
            END;
            //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
            //se agrego rango de facturas
            IF (FirstFactCf <> '') OR (LastFactCf <> '') THEN BEGIN
                rNoSeriesLn.RESET;
                rNoSeriesLn.SETRANGE("Series Code", rNoSeries.Code);
                IF rNoSeriesLn.FINDFIRST THEN
                    REPEAT
                        IF (rNoSeriesLn."Starting No." <= FirstFactCf) AND (rNoSeriesLn."Ending No." >= FirstFactCf) THEN
                            vFirstFactCFAut := UPPERCASE(rNoSeriesLn.Series);
                        IF (rNoSeriesLn."Starting No." <= LastFactCf) AND (rNoSeriesLn."Ending No." >= LastFactCf) THEN
                            vLastFactCFAut := UPPERCASE(rNoSeriesLn.Series);
                    UNTIL rNoSeriesLn.NEXT = 0;

                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := 'Del No.: ' + vFirstFactCFAut + ' ' + FirstFactCf;
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                DSTR1 := COPYSTR('#L######################################', 1);
                Value[1] := 'Al No.: ' + vLastFactCFAut + ' ' + LastFactCf;
                PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END;

            //Se quito que imprimiera los rango de facturas porq no es un solo pos en la tienda
            //Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            VentasG := VentasG - TotalVentNcr + vTotalDocDevolucion + VentasEDevDocDev;
            //VENTAS GRAVADAS...
            DSTR1 := COPYSTR('#L##############    #R##################', 1);
            Value[1] := 'Ventas Gravadas:';
            Value[2] := '$' + FORMAT(VentasG, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            TotalIva := TotalIva - TotalIvaNcr + vTotalIvaDocDevolucion;
            //IMPUESTO IVA...
            DSTR1 := COPYSTR('#L###########       #R##################', 1);
            Value[1] := 'Impuesto IVA:';
            Value[2] := '$' + FORMAT(TotalIva - vCESC, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            //IMPUESTO CESC...
            DSTR1 := COPYSTR('#L############           #R#############', 1);
            Value[1] := 'Impuesto CESC:';
            Value[2] := '$' + FORMAT(vCESC, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            //Total Gravado...
            DSTR1 := COPYSTR('#L############      #R##################', 1);
            Value[1] := 'Total Gravado:';
            Value[2] := '$' + FORMAT(VentasG + TotalIva, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            //PERCEPCION...
            DSTR1 := COPYSTR('#L################# #R##################', 1);
            Value[1] := '(-) IVA Retenido:';
            Value[2] := '$' + FORMAT((Retencion - vTotalRetencionDev), 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            //VENTAS EXENTAS...
            DSTR1 := COPYSTR('#L#############     #R##################', 1);
            Value[1] := 'Ventas Exentas:';
            Value[2] := '$' + FORMAT((VentasE - VentasEDev - VentasEDevDocDev), 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            //VENTAS NO SUJETAS...
            DSTR1 := COPYSTR('#L################  #R##################', 1);
            Value[1] := 'Ventas No Sujetas:';
            Value[2] := '$' + FORMAT((VentasNoSu - VentasNoSuDev), 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            //VENTAS TOTALES
            DSTR1 := COPYSTR('#L#############     #R##################', 1);
            Value[1] := 'Ventas Totales:';
            Value[2] := '$' + FORMAT((VentasG + TotalIva + VentasE + VentasNoSu) - (VentasEDev + VentasNoSuDev + (Retencion - RetencionDev) + VentasEDevDocDev), 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            vVentasGravadasTotales := vVentasGravadasTotales + VentasG;
            vImpuestoIVATotales := vImpuestoIVATotales + TotalIva - vCESC;
            vCESCTotales := vCESCTotales + vCESC;
            vTotalGravadoTotales := vTotalGravadoTotales + (VentasG + TotalIva);
            vVentasExentasTotales := vVentasExentasTotales + (VentasE - VentasEDev);
            vVentasNoSujetasTotales := vVentasNoSujetasTotales + (VentasNoSu - VentasNoSuDev);
            vVentasTotalesTotales := vVentasTotalesTotales + ((VentasG + TotalIva + VentasE + VentasNoSu) - (VentasEDev + VentasNoSuDev + (Retencion - RetencionDev) + VentasEDevDocDev));
            vIVARetenidoTotales := vIVARetenidoTotales + (Retencion - RetencionDev);

            //LIMPIO LAS VARIABLES QUE MUESTRAN LOS TOTALES DE LAS VENTAS POR TIPO DE COMPROBANTES.
            CLEAR(Venta);
            CLEAR(Iva);
            CLEAR(vTotal);
            CLEAR(VentasG);
            CLEAR(TotalIva);
            CLEAR(TotalVentNcr);
            CLEAR(TotalIvaNcr);
            CLEAR(VentasE);
            CLEAR(VentasNoSu);
            CLEAR(VentasEDev);
            CLEAR(VentasNoSuDev);
            CLEAR(vTotalDocDevolucion);

            //Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            DSTR1 := COPYSTR('#C######################################', 1);
            Value[1] := 'VENTAS TOTALES';
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

            //Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //VENTAS GRAVADAS TOTALES
            DSTR1 := COPYSTR('#L###################### #R#############', 1);
            Value[1] := 'Ventas Gravadas:';
            Value[2] := '$' + FORMAT(vVentasGravadasTotales, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //IMPUESTO IVA TOTALES
            DSTR1 := COPYSTR('#L###################### #R#############', 1);
            Value[1] := 'Impuesto IVA:';
            Value[2] := '$' + FORMAT(vImpuestoIVATotales, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //IMPUESTO CESC TOTALES
            DSTR1 := COPYSTR('#L###################### #R#############', 1);
            Value[1] := 'Impuesto CESC:';
            Value[2] := '$' + FORMAT(vCESCTotales, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //TOTAL GRAVADO TOTALES
            DSTR1 := COPYSTR('#L###################### #R#############', 1);
            Value[1] := 'Total Gravado:';
            Value[2] := '$' + FORMAT(vTotalGravadoTotales, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //VENTAS EXENTAS TOTALES
            DSTR1 := COPYSTR('#L###################### #R#############', 1);
            Value[1] := 'Ventas Exentas:';
            Value[2] := '$' + FORMAT(vVentasExentasTotales, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //VENTAS NO SUJETAS TOTALES
            DSTR1 := COPYSTR('#L###################### #R#############', 1);
            Value[1] := 'Ventas No Sujetas:';
            Value[2] := '$' + FORMAT(vVentasNoSujetasTotales, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //IVA PERCIBIDO TOTALES
            DSTR1 := COPYSTR('#L###################### #R#############', 1);
            Value[1] := '(+) IVA Percebido:';
            Value[2] := '$' + FORMAT(vIVAPercibidoTotales - vIVAPercibidoDevTotales, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //IVA RETENIDO TOTALES
            DSTR1 := COPYSTR('#L###################### #R#############', 1);
            Value[1] := '(-) IVA Retenido:';
            Value[2] := '$' + FORMAT(vIVARetenidoTotales, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //VENTAS TOTALES TOTALES
            DSTR1 := COPYSTR('#L###################### #R#############', 1);
            Value[1] := 'Ventas Totales:';
            Value[2] := '$' + FORMAT(vVentasTotalesTotales, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //se agregaron devoluciones
            //Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //TOTAL DEVOLUCIONES
            //ENCABEZADO PARA EL TIPO DE COMPROBANTE
            DSTR1 := COPYSTR('#C######################################', 1);
            Value[1] := 'DEVOLUCIONES';
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

            Transaction2.RESET;
            Transaction2.SETCURRENTKEY("Statement Code", "Z-Report ID", "Transaction Type", "Entry Status");
            Transaction2.SETRANGE(Transaction2."POS Terminal No.", POSSESSION.TerminalNo());
            Transaction2.SETRANGE("Statement Code", SCode);
            Transaction2.SETFILTER("Z-Report ID", '<>%1', '');
            Transaction2.SETRANGE("Transaction Type", Transaction2."Transaction Type"::Sales);
            Transaction2.SETFILTER("Entry Status", '%1|%2', Transaction2."Entry Status"::" ", Transaction2."Entry Status"::Posted);
            Transaction2.SETRANGE("Sale Is Return Sale", TRUE);
            Transaction2.SETRANGE(Date, InicPeriodo, FinPeriodo);
            vNoDevoluciones := 0;
            IF Transaction2.FINDFIRST THEN BEGIN
                REPEAT
                    vNoDevoluciones := (vNoDevoluciones + 1);
                    CLEAR(Venta);
                    CLEAR(Iva);
                    CLEAR(vTotal);
                    rSalesEntry.SETRANGE("Store No.", Transaction2."Store No.");
                    rSalesEntry.SETRANGE("POS Terminal No.", Transaction2."POS Terminal No.");
                    rSalesEntry.SETRANGE("Transaction No.", Transaction2."Transaction No.");
                    IF rSalesEntry.FIND('-') THEN
                        REPEAT
                            Venta += ABS(rSalesEntry."Net Amount");
                            Iva += ABS(rSalesEntry."VAT Amount");
                            vTotal += ABS(rSalesEntry."Net Amount") + ABS(rSalesEntry."VAT Amount");

                            IF rSalesEntry."VAT Amount" <> 0 THEN BEGIN
                                IF NOT Transaction2."Sale Is Return Sale" THEN BEGIN
                                    VentasG += ABS(rSalesEntry."Net Amount");
                                    TotalIva += ABS(rSalesEntry."VAT Amount");
                                END
                                ELSE BEGIN
                                    TotalVentNcr += ABS(rSalesEntry."Net Amount");
                                    TotalIvaNcr += ABS(rSalesEntry."VAT Amount");
                                END;
                            END
                            ELSE BEGIN
                                IF rSalesEntry."VAT Amount" = 0 THEN BEGIN
                                    IF NOT Transaction2."Sale Is Return Sale" THEN
                                        VentasE += ABS(rSalesEntry."Net Amount")
                                    ELSE
                                        VentasEDev += ABS(rSalesEntry."Net Amount")
                                END;
                            END;
                        UNTIL rSalesEntry.NEXT = 0;
                UNTIL Transaction2.NEXT = 0;
            END;

            //DEVOLUCIONES...
            DSTR1 := COPYSTR('#L#################### #L#############', 1);
            Value[1] := 'Cantidad devoluciones:';
            Value[2] := FORMAT(vNoDevoluciones);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            VentasG := VentasG - TotalVentNcr;
            TotalIva := TotalIva - TotalIvaNcr;

            //VENTAS TOTALES
            DSTR1 := COPYSTR('#L################### #R################', 1);
            Value[1] := 'Devoluciones Totales:';
            Value[2] := '$' + FORMAT((VentasG + TotalIva + VentasE + VentasNoSu) - (VentasEDev + VentasNoSuDev) + vTotalRetencionDev - vIVAPercibidoDevTotales, 0, '<Integer Thousand><Decimals,3>');
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            //LIMPIO LAS VARIABLES QUE MUESTRAN LOS TOTALES DE LAS VENTAS POR TIPO DE COMPROBANTES.
            CLEAR(FirstTicket);
            CLEAR(LastTicket);
            CLEAR(Venta);
            CLEAR(Iva);
            CLEAR(vTotal);
            CLEAR(VentasG);
            CLEAR(TotalIva);
            CLEAR(TotalVentNcr);
            CLEAR(TotalIvaNcr);
            CLEAR(VentasE);
            CLEAR(VentasNoSu);
            CLEAR(VentasEDev);
            CLEAR(VentasNoSuDev);

            //Imprimir Linea en blanco...
            DSTR1 := COPYSTR('                     ', 1);
            PrintUL.PrintLine(2, PrintUL.FormatLine(PrintUL.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;

        IF DoZ THEN BEGIN
            Terminal."FSN Last Z-ReportM" := INCSTR(Terminal."FSN Last Z-ReportM");
            Terminal.MODIFY;
        END;
        Commit();
        IF NOT PrintUL.ClosePrinter(2) THEN
            EXIT(FALSE);

        EXIT(TRUE);

    end;

    [EventSubscriber(ObjectType::Table, Database::"Report Selections", 'OnBeforePrintDocument', '', true, true)]
    local procedure "Report Selections_OnBeforePrintDocument"
    (
        TempReportSelections: Record "Report Selections";
        IsGUI: Boolean;
        RecVarToPrint: Variant;
        var IsHandled: Boolean
    )
    begin
        if TempReportSelections."Report ID" = 1401 then begin
            REPORT.RunModal(50007, IsGUI, false, RecVarToPrint);
            IsHandled := true;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Print Utility", 'OnPrintExtraSlipFieldNameValue', '', true, true)]
    local procedure "LSC POS Print Utility_OnPrintExtraSlipFieldNameValue"
    (
        Transaction: Record "LSC Transaction Header";
        var FieldName: array[20] of Text[2];
        var FieldValue: array[20] of Text[50];
        var LastIndex: Integer
    )
    var
        MembershipC: Record "LSC Membership Card";
        MemberAc: Record "LSC Member Account";
    begin
        if MembershipC.Get(Transaction."Member Card No.") then begin
            if MemberAc.Get(MembershipC."Account No.") then;
            FieldName[18] := 'NA'; //Nombre de cliente
            FieldValue[18] := CopyStr(MemberAc.Description, 1, 50);
            FieldName[19] := 'VI'; //Numero de tarjeta
            FieldValue[19] := MembershipC."Card No.";
            FieldName[20] := 'FE'; //Fecha de vencimiento 
            FieldValue[20] := Format(MembershipC."Last Valid Date");
            LastIndex := 20;
        end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Print Utility", 'OnBeforePrintVoidSlip', '', true, true)]
    local procedure "LSC POS Print Utility_OnBeforePrintVoidSlip"
    (
        var Transaction: Record "LSC Transaction Header";
        var PrintBuffer: Record "LSC POS Print Buffer";
        var PrintBufferIndex: Integer;
        var LinesPrinted: Integer;
        var DSTR1: Text[100];
        var IsHandled: Boolean;
        var ReturnValue: Boolean
    )
    var
        parameter: Record "FSN Parameter";
    begin

        //detiene la imprecion de recivo para transacciones anuladas
        if parameter.Get('PRINT', 'TRANSVOID') then
            IF parameter.Activo THEN BEGIN
                IsHandled := true;
                ReturnValue := IsHandled;
            END;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterVoidPressed', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterVoidPressed"(var POSTransaction: Record "LSC POS Transaction")
    var
        parameter: Record "FSN Parameter";
    begin
        if parameter.Get('PRINT', 'TRANSVOID') then
            IF parameter.Activo THEN BEGIN
                PrintSlipVoid(POSTransaction);
            END;
    end;


    local procedure PrintSlipVoid(POSTrans: Record "LSC POS Transaction"): Boolean
    var
        PrintUtil: Codeunit "LSC POS Print Utility";
        xPosTrLines: Record "LSC POS Trans. Line";
        xStore: Record "LSC Store";
        rDeliveryOrder: Record "LSC Delivery Order";
        xDireccion: Text[250];
        xItem: Record "Item";
        xNewText: Text[50];
        xInt: Integer;
        xToInt: Integer;
        xStrFrom: Integer;
        xFreeText: Text[250];
        PosFunc: codeunit "LSC POS Functions";
        Tray: Integer;
        HoraEntrega: Time;
        xInfoCodeEntry: Record "LSC POS Trans. Infocode Entry";
        xStaff: Record "LSC Staff";
        FSNUtil: Codeunit "FSN Utility";
        TCommand, TransactorText, Tresponse, Response_Text : Text;
        countDescription: Integer;
        logitud: Integer;
        Text000: Label 'VOID TRANSACTION';
    begin
        Clear(xDireccion);
        countDescription := 0;
        POSTrans.reset;

        PosFunc.InitPosFunctions;
        PosFunc.PosTransDiscLoad(POSTrans."Receipt No.");
        Clear(PrintUtil);
        if not PrintUtil.OpenReceiptPrinter(2, 'PR', '', 0, POSTrans."Receipt No.") then
            exit(false);

        Tray := 2;

        DSTR1 := '#C######################################';
        Value[1] := '';
        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        DSTR1 := '#C######################################';
        Value[1] := Text000;
        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        PrintUtil.PrintSeperator(Tray);
        DSTR1 := '#L######################################';
        // Linea de Farmacia
        IF xStore.GET(POSTrans."Store No.") THEN
            Value[1] := 'FASANI: ' + xStore.Name
        ELSE
            Value[1] := 'FASANI: ____________________';
        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        PrintUtil.PrintSeperator(Tray);

        IF NOT IsDeliveryCopy THEN BEGIN
            DSTR1 := '#L######################################';
            CLEAR(xPosTrLines);
            xPosTrLines.RESET;
            xPosTrLines.SETRANGE("Receipt No.", POSTrans."Receipt No.");
            xPosTrLines.SETRANGE("Entry Type", xPosTrLines."Entry Type"::Item);
            xPosTrLines.SETFILTER("Entry Status", '<>%1', xPosTrLines."Entry Status"::Voided);
            IF xPosTrLines.FIND('-') THEN
                REPEAT
                    countDescription := 0;
                    IF xItem.GET(xPosTrLines.Number) THEN BEGIN
                        DSTR1 := '#L######################################';
                        Value[1] := '*** ' + COPYSTR(xItem."LSC Attrib 1 Code", 1, 30) + ' ***';
                        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                        DSTR1 := '#L# #L##################################';
                        Value[1] := FORMAT(xPosTrLines.Quantity);

                        IF (xPosTrLines."Barcode No." <> '') THEN BEGIN
                            IF rBarras.GET(xPosTrLines."Barcode No.") THEN BEGIN
                                Value[2] := COPYSTR(rBarras.Description, 1, 35);
                                countDescription := StrLen(xItem.Description);
                                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                            END ELSE BEGIN
                                Value[2] := COPYSTR(xItem.Description, 1, 35);
                                countDescription := StrLen(xItem.Description);
                                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;
                        END
                        ELSE BEGIN
                            Value[2] := COPYSTR(xItem.Description, 1, 35);
                            countDescription := StrLen(xItem.Description);
                            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        END;

                        if countDescription > 35 then begin
                            DSTR1 := '#L# #L##################################';
                            Value[1] := ' ';
                            Value[2] := COPYSTR(xItem.Description, 36, countDescription);
                            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        end;

                        DSTR1 := 'PLU:1234567 1234567890123456789012345678';
                        DSTR1 := '#L######### #L##########################';
                        Value[1] := 'PLU:' + xPosTrLines.Number;
                        Value[2] := xPosTrLines."Unit of Measure";
                        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END;
                UNTIL xPosTrLines.NEXT = 0;
        END ELSE BEGIN
            DSTR1 := '#L######### #L##########################';
            Value[1] := 'COPIA';
            Value[2] := '******************';
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;//isCopy

        PrintUtil.PrintSeperator(Tray);

        DSTR1 := '#L######################################';
        Value[1] := 'Fecha: ' + FORMAT(WORKDATE, 10, '<Day,2>/<Month,2>/<Year4>') + ' ' + FORMAT(TIME, 14, '<Hours12>:<Minutes,2>:<Seconds,2> <AM/PM>');
        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        Value[1] := '';
        Value[2] := '';
        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        PrintUtil.ClosePrinter(2);
        exit(true);

    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Print Utility", 'OnBeforePrintCIDReport', '', true, true)]
    local procedure "LSC POS Print Utility_OnBeforePrintCIDReport"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var Transaction: Record "LSC Transaction Header";
        var PrintBuffer: Record "LSC POS Print Buffer";
        var PrintBufferIndex: Integer;
        var LinesPrinted: Integer;
        var DSTR1: Text[100];
        var IsHandled: Boolean;
        var ReturnValue: Boolean
    )
    var
        Parameter: Record "FSN Parameter";
        POSSESION: Codeunit "LSC POS Session";
    begin
        if (Parameter.Get('ROBOT', 'PROCESS')) and Parameter.Activo then begin
            if Parameter."Value Text 1" = POSSESION.TerminalNo() THEN
                PrintCIDReport(POSTransaction, true)
            else
                PrintCIDReport(POSTransaction, false);
            IsHandled := true;
            ReturnValue := IsHandled;
        end;
    end;



    procedure PrintCIDReport(PosTrans: Record "LSC POS Transaction"; Principal: Boolean): Boolean
    var
        PaymTrans2: Record "LSC Trans. Payment Entry";
        PaymTrans3: Record "LSC Trans. Payment Entry";
        PaymTemp: Record "LSC Trans. Payment Entry" temporary;
        Terminal: Record "LSC POS Terminal";
        Staff: Record "LSC Staff";
        StoreRec: Record "LSC Store";
        CurrencyRec: Record Currency;
        lTenderType: Record "LSC Tender Type";
        PosStartStat: Record "LSC POS Start Status";
        CashDeclTmp: Record "LSC POS Cash Declaration" temporary;
        CashDeclTmp2: Record "LSC POS Cash Declaration" temporary;
        PosCashDeclTmp: Record "LSC POS Cash Declaration" temporary;
        Transaction: Record "LSC Transaction Header";
        TSUtil: Codeunit "LSC POS Trans. Server Utility";
        DSTR1: Text[80];
        tmpSTR: Text[80];
        tmpSTR2: Text[80];
        SCode: Code[20];
        ZReportID: Code[10];
        FloatTotal: Decimal;
        RemoveTotal: Decimal;
        SalesTotal: Decimal;
        SuspPrepayment: Decimal;
        RecCount: Integer;
        TransNotSendt: Integer;
        NoSuspended: Integer;
        NoSuspPrepayment: Integer;
        FromTransNo: Integer;
        CounterOk: Boolean;
        IsHandled: Boolean;
        ReturnValue: Boolean;
        Text156: Label 'CID-REPORT';
        Text078: Label 'Store no.';
        Text079: Label 'Terminal';
        Text048: Label 'Date';
        Text051: Label 'Staff';
        Text159: Label 'Tender Type';
        Text160: Label 'Qty.';
        Text004: Label 'Amount';
        Terminals: Record "LSC POS Terminal";
    begin
        if not Staff.Get(Globals.StaffID) then
            exit(true);

        if not Terminal.Get(Globals.TerminalNo) then
            exit(true);

        if not StoreRec.Get(Globals.StoreNo) then
            exit(true);

        Clear(CashDeclTmp);
        CashDeclTmp.DeleteAll;
        Clear(CashDeclTmp2);
        CashDeclTmp2.DeleteAll;
        CounterOk := false;

        lTenderType.Reset;
        lTenderType.SetCurrentKey("Store No.");
        lTenderType.SetRange("Store No.", Globals.StoreNo);
        lTenderType.SetFilter("Function", '<>%1', lTenderType."Function"::"Tender Remove/Float");
        lTenderType.SetRange("Print in CID Report", true);
        if not lTenderType.FindSet() then
            exit(true);

        CalcPaymentEntry(PosTrans, CashDeclTmp2, 1);

        repeat
            if lTenderType."Foreign Currency" then begin
                Clear(CurrencyRec);
                if CurrencyRec.FindSet then begin
                    repeat
                        if CashDeclTmp2.Get('', lTenderType.Code, CurrencyRec.Code) then begin
                            CashDeclTmp."Tender Type" := lTenderType.Code;
                            CashDeclTmp."Currency Code" := CurrencyRec.Code;
                            CashDeclTmp.Amount := CashDeclTmp2."Trans. Amount";
                            CashDeclTmp.Counter := CashDeclTmp2.Counter;
                            if CashDeclTmp.Counter <> 0 then
                                CounterOk := true;
                            CashDeclTmp.Insert;
                        end;
                    until CurrencyRec.Next = 0;
                end;
            end
            else begin
                if CashDeclTmp2.Get('', lTenderType.Code, '') then begin
                    CashDeclTmp."Tender Type" := lTenderType.Code;

                    CashDeclTmp."Currency Code" := '';

                    CashDeclTmp.Amount := CashDeclTmp2."Trans. Amount";
                    CashDeclTmp.Counter := CashDeclTmp2.Counter;
                    if CashDeclTmp.Counter <> 0 then
                        CounterOk := true;
                    CashDeclTmp.Insert;
                end;
            end;
        until lTenderType.Next = 0;

        if not PrintUtil.OpenReceiptPrinter(2, 'TENDER', 'CID', Transaction."Transaction No.", Transaction."Receipt No.") then
            exit(false);

        if not Terminal."Terminal Statement" then
            Terminal."Statement Method" := Store."Statement Method";

        DSTR1 := '#L####### #L########';
        FieldValue[1] := Text079 + ':';
        FieldValue[2] := Terminal."No.";
        PrintUtil.PrintLine(2, PrintUtil.FormatLine(PrintUtil.FormatStr(FieldValue, DSTR1), false, true, false, false));
        PrintUtil.PrintSeperator(2);

        Transaction.Date := PosTrans."Trans. Date";
        Transaction.Time := PosTrans."Trans Time";
        PrintUtil.PrintLogo(2);
        PrintUtil.PrintHeader(Transaction, false, 2);

        DSTR1 := '#L#### #T###### #T#### ';
        FieldValue[1] := Text048 + ':';
        FieldValue[2] := Format(Today());
        FieldValue[3] := Format(Time(), 5);
        PrintUtil.PrintLine(2, PrintUtil.FormatLine(PrintUtil.FormatStr(FieldValue, DSTR1), false, true, false, false));

        DSTR1 := '#L###### #L############';
        FieldValue[1] := Text051 + ':';
        if Staff."Name on Receipt" <> '' then
            FieldValue[2] := Staff."Name on Receipt"
        else
            FieldValue[2] := Globals.StaffID;
        PrintUtil.PrintLine(2, PrintUtil.FormatLine(PrintUtil.FormatStr(FieldValue, DSTR1), false, true, false, false));
        PrintUtil.PrintSeperator(2);

        DSTR1 := '#C###################';

        FieldValue[1] := Text156;
        PrintUtil.PrintLine(2, PrintUtil.FormatLine(PrintUtil.FormatStr(FieldValue, DSTR1), true, true, true, false));
        PrintUtil.PrintSeperator(2);

        Clear(FieldValue);
        if CounterOk then begin
            DSTR1 := '#L############ #R## #R##################';
            FieldValue[1] := Text159;
            FieldValue[2] := Text160;
            FieldValue[3] := Text004;
        end
        else begin
            DSTR1 := '#L################# #R##################';
            FieldValue[1] := Text159;
            FieldValue[2] := Text004;
        end;
        PrintUtil.PrintSeperator(2);

        PrintUtil.PrintLine(2, PrintUtil.FormatLine(PrintUtil.FormatStr(FieldValue, DSTR1), false, true, false, false));
        PrintUtil.PrintSeperator(2);

        SCode := POSFunctions.GetStatementCode;

        Clear(CashDeclTmp);
        if CashDeclTmp.FindSet then begin
            Clear(FieldValue);
            if CounterOk then
                DSTR1 := '#L############ #R## #R##################'
            else
                DSTR1 := '#L################# #R##################';

            repeat
                lTenderType.Get(StoreRec."No.", CashDeclTmp."Tender Type");
                if (CashDeclTmp."Currency Code" <> '') then begin
                    CurrencyRec.Get(CashDeclTmp."Currency Code");
                    FieldValue[1] := CurrencyRec.Description;
                end
                else begin
                    FieldValue[1] := lTenderType.Description;
                end;

                if CounterOk then begin
                    FieldValue[2] := POSFunctions.FormatQty(CashDeclTmp."Trans. Amount");
                    FieldValue[3] := POSFunctions.FormatAmount(CashDeclTmp.Amount);
                end
                else begin
                    FieldValue[2] := POSFunctions.FormatAmount(CashDeclTmp.Amount);
                end;

                PrintUtil.PrintLine(2, PrintUtil.FormatLine(PrintUtil.FormatStr(FieldValue, DSTR1), false, false, false, false));
            until CashDeclTmp.Next = 0;
        end;

        /////////////////////////////////
        Terminals.Reset();
        Terminals.SetRange("Store No.", Globals.StoreNo);
        Terminals.SetRange("Menu Profile", '#FSNMASTER');
        if not Principal then
            Terminals.SetRange("No.", PosTrans."POS Terminal No.");
        if Terminals.FindSet() then begin
            PrintUtil.PrintSeperator(2);
            FieldValue[1] := 'MONTO EN RUTA:';
            PrintUtil.PrintLine(2, PrintUtil.FormatLine(PrintUtil.FormatStr(FieldValue, '#C###################'), true, true, true, false));
            PrintUtil.PrintSeperator(2);
            repeat
                DSTR1 := '#L####### #L########';
                FieldValue[1] := Text079 + ':';
                FieldValue[2] := Terminals."No.";
                PrintUtil.PrintLine(2, PrintUtil.FormatLine(PrintUtil.FormatStr(FieldValue, DSTR1), false, true, false, false));
                PrintUtil.PrintSeperator(2);
                Clear(CashDeclTmp);
                CashDeclTmp.DeleteAll;
                Clear(CashDeclTmp2);
                CashDeclTmp2.DeleteAll;
                Clear(PosCashDeclTmp);
                PosCashDeclTmp.DeleteAll;
                CounterOk := false;

                lTenderType.Reset;
                lTenderType.SetCurrentKey("Store No.");
                lTenderType.SetRange("Store No.", Globals.StoreNo);
                lTenderType.SetFilter("Function", '<>%1', lTenderType."Function"::"Tender Remove/Float");
                lTenderType.SetRange("Print in CID Report", true);
                if not lTenderType.FindSet() then
                    exit(true);
                MontoDAF(CashDeclTmp2, PosCashDeclTmp, Terminals."No.");
                repeat
                    if lTenderType."Foreign Currency" then begin
                        Clear(CurrencyRec);
                        if CurrencyRec.FindSet then begin
                            repeat
                                if CashDeclTmp2.Get('', lTenderType.Code, CurrencyRec.Code) then begin
                                    CashDeclTmp."Tender Type" := lTenderType.Code;
                                    CashDeclTmp."Currency Code" := CurrencyRec.Code;
                                    CashDeclTmp.Amount := CashDeclTmp2."Trans. Amount";
                                    CashDeclTmp.Counter := CashDeclTmp2.Counter;
                                    if CashDeclTmp.Counter <> 0 then
                                        CounterOk := true;
                                    CashDeclTmp.Insert;
                                end;
                            until CurrencyRec.Next = 0;
                        end;
                    end
                    else begin
                        if CashDeclTmp2.Get('', lTenderType.Code, '') then begin
                            CashDeclTmp."Tender Type" := lTenderType.Code;

                            CashDeclTmp."Currency Code" := '';

                            CashDeclTmp.Amount := CashDeclTmp2."Trans. Amount";
                            CashDeclTmp.Counter := CashDeclTmp2.Counter;
                            if CashDeclTmp.Counter <> 0 then
                                CounterOk := true;
                            CashDeclTmp.Insert;
                        end;
                    end;
                until lTenderType.Next = 0;
                Clear(CashDeclTmp);
                if CashDeclTmp.FindSet then begin
                    Clear(FieldValue);
                    if CounterOk then
                        DSTR1 := '#L############ #R## #R##################'
                    else
                        DSTR1 := '#L################# #R##################';

                    repeat
                        lTenderType.Get(StoreRec."No.", CashDeclTmp."Tender Type");
                        if (CashDeclTmp."Currency Code" <> '') then begin
                            CurrencyRec.Get(CashDeclTmp."Currency Code");
                            FieldValue[1] := CurrencyRec.Description;
                        end
                        else begin
                            FieldValue[1] := lTenderType.Description;
                        end;

                        if CounterOk then begin
                            FieldValue[2] := POSFunctions.FormatQty(CashDeclTmp."Trans. Amount");
                            FieldValue[3] := POSFunctions.FormatAmount(CashDeclTmp.Amount);
                        end
                        else begin
                            FieldValue[2] := POSFunctions.FormatAmount(CashDeclTmp.Amount);
                        end;

                        PrintUtil.PrintLine(2, PrintUtil.FormatLine(PrintUtil.FormatStr(FieldValue, DSTR1), false, false, false, false));

                        if lTenderType.Code = '1' then begin
                            if (PosCashDeclTmp."Currency Code" <> '') then begin
                                CurrencyRec.Get(PosCashDeclTmp."Currency Code");
                                FieldValue[1] := CurrencyRec.Description;
                            end
                            else begin
                                FieldValue[1] := 'Cambio';
                            end;
                            FieldValue[2] := POSFunctions.FormatQty(PosCashDeclTmp."Trans. Amount");

                            PrintUtil.PrintLine(2, PrintUtil.FormatLine(PrintUtil.FormatStr(FieldValue, DSTR1), false, false, false, false));
                        end;
                    until CashDeclTmp.Next = 0;
                end;
                PrintUtil.PrintSeperator(2);
            until Terminals.Next = 0;
        end;
        if not PrintUtil.ClosePrinter(2) then
            exit(false);
        exit(true);
    end;

    procedure CalcPaymentEntry(PosTrans: Record "LSC POS Transaction"; var PosCashDeclTmp: Record "LSC POS Cash Declaration"; Type: Integer)
    var
        PosStartStat: Record "LSC POS Start Status";
        PosCashDecl: Record "LSC POS Cash Declaration";
        PayEntry: Record "LSC Trans. Payment Entry";
        ErrorCode: Integer;
        CalcLocal: Boolean;
        InfocodeEntry: Record "LSC Trans. Infocode Entry";
    begin
        Store.Get(PosTrans."Store No.");
        PosFuncProfile.Get(Globals.FunctionalityProfileID);

        if Store."Statement Method" = Store."Statement Method"::Staff then begin
            //*********************************
            //* Staff
            //*********************************
            if not PosStartStat.Get(PosTrans."Store No.", PosStartStat.Type::Staff, PosTrans."Staff ID") then begin
                PosStartStat."Store No." := PosTrans."Store No.";
                PosStartStat.Type := PosStartStat.Type::Staff;
                PosStartStat.ID := PosTrans."Staff ID";
                PosStartStat."Next Tender Decl. ID" := '0000000001';
            end;

            CalcLocal := true;
            if PosFuncProfile."TS POS Cash Mgt." then begin
                if TSUtil.Initialize then begin
                    if TSUtil.CreateTmpTotalPayment(PosTrans, Type) then
                        if TSUtil.GetTotalPayment(PosStartStat, ErrorCode) then
                            if TSUtil.FirstTmpTotalPayment(PosCashDecl) then begin
                                CalcLocal := false;
                                repeat
                                    if PosCashDeclTmp.Get('', PosCashDecl."Tender Type", PosCashDecl."Currency Code", PosCashDecl."Card No.") then begin
                                        PosCashDeclTmp."Trans. Amount" := PosCashDeclTmp."Trans. Amount" + PosCashDecl."Trans. Amount";
                                        PosCashDeclTmp.Modify;
                                    end
                                    else begin
                                        Clear(PosCashDeclTmp);
                                        PosCashDeclTmp."Tender Type" := PosCashDecl."Tender Type";
                                        PosCashDeclTmp."Currency Code" := PosCashDecl."Currency Code";
                                        PosCashDeclTmp."Card No." := PosCashDecl."Card No.";
                                        PosCashDeclTmp."Trans. Amount" := PosCashDecl."Trans. Amount";
                                        PosCashDeclTmp.Insert;
                                    end;
                                until (TSUtil.NextTmpTotalPayment(PosCashDecl) = false);
                            end;
                end;
            end;

            if CalcLocal then begin
                Clear(PayEntry);
                PayEntry.SetCurrentKey("Staff ID", "Tender Decl. ID", "Tender Type", "Currency Code");
                PayEntry.SetRange("Staff ID", PosStartStat.ID);
                PayEntry.SetRange("Tender Decl. ID", PosStartStat."Next Tender Decl. ID");
                PayEntry.SetRange("Store No.", PosTrans."Store No.");
                if PayEntry.FindFirst then
                    repeat
                        if PosCashDeclTmp.Get('', PayEntry."Tender Type", PayEntry."Currency Code", PayEntry."Card No.") then begin
                            PosCashDeclTmp."Trans. Amount" := PosCashDeclTmp."Trans. Amount" + PayEntry."Amount in Currency";
                            PosCashDeclTmp.Modify;
                        end
                        else begin
                            Clear(PosCashDeclTmp);
                            PosCashDeclTmp."Tender Type" := PayEntry."Tender Type";
                            PosCashDeclTmp."Currency Code" := PayEntry."Currency Code";
                            PosCashDeclTmp."Card No." := PayEntry."Card No.";
                            PosCashDeclTmp."Trans. Amount" := PayEntry."Amount in Currency";
                            PosCashDeclTmp.Insert;
                        end;
                    until PayEntry.Next = 0;
            end;
        end
        else begin
            //*********************************
            //* POS Terminal
            //*********************************
            if not PosStartStat.Get(PosTrans."Store No.", PosStartStat.Type::"POS Terminal", PosTrans."POS Terminal No.") then begin
                PosStartStat."Store No." := PosTrans."Store No.";
                PosStartStat.Type := PosStartStat.Type::"POS Terminal";
                PosStartStat.ID := PosTrans."POS Terminal No.";
                PosStartStat."Next Tender Decl. ID" := '0000000001';
            end;
            Clear(PayEntry);
            PayEntry.SetCurrentKey("Tender Decl. ID", "Tender Type", "Currency Code");
            PayEntry.SetRange("Tender Decl. ID", PosStartStat."Next Tender Decl. ID");
            PayEntry.SetRange("Store No.", PosTrans."Store No.");
            PayEntry.SetRange("POS Terminal No.", PosTrans."POS Terminal No.");
            if PayEntry.FindFirst then
                repeat
                    if PosCashDeclTmp.Get('', PayEntry."Tender Type", PayEntry."Currency Code", PayEntry."Card No.") then begin
                        PosCashDeclTmp."Trans. Amount" := PosCashDeclTmp."Trans. Amount" + PayEntry."Amount in Currency";
                        PosCashDeclTmp.Modify;
                    end
                    else begin
                        Clear(PosCashDeclTmp);
                        PosCashDeclTmp."Tender Type" := PayEntry."Tender Type";
                        PosCashDeclTmp."Currency Code" := PayEntry."Currency Code";
                        PosCashDeclTmp."Card No." := PayEntry."Card No.";
                        PosCashDeclTmp."Trans. Amount" := PayEntry."Amount in Currency";
                        PosCashDeclTmp.Insert;
                    end;
                until PayEntry.Next = 0;
        end;
    end;

    procedure MontoDAF(VAR PosCashDeclTmp: Record "LSC POS Cash Declaration"; VAR PosCashDecChanlTmp: Record "LSC POS Cash Declaration"; Terminal: Code[20])
    var
        // myInt: Integer;DeliveryDriverTrip: Record "LSC Delivery Driver Trip";
        DeliveryDriverTrip: Record "LSC Delivery Driver Trip";
        DeliveryTrip_l: Record "FSN Delivery Trip";
        TransHeader: Record "LSC Transaction Header";
        PayEntry: Record "LSC Trans. Payment Entry";
    begin

        DeliveryDriverTrip.RESET;
        DeliveryDriverTrip.SETCURRENTKEY(DeliveryDriverTrip."Driver ID", DeliveryDriverTrip."Store No.", DeliveryDriverTrip."Trip Counter");
        DeliveryDriverTrip.SETRANGE(DeliveryDriverTrip."Store No.", 'F010');
        DeliveryDriverTrip.SetRange(Status, DeliveryDriverTrip.Status::Open);
        if DeliveryDriverTrip.Find('-') then begin
            repeat
                DeliveryTrip_l.RESET;
                DeliveryTrip_l.SETRANGE(DeliveryTrip_l."Store No.", DeliveryDriverTrip."Store No.");
                DeliveryTrip_l.SETRANGE(DeliveryTrip_l."Driver ID", DeliveryDriverTrip."Driver ID");
                DeliveryTrip_l.SETRANGE(DeliveryTrip_l."Trip No. (LS Retail)", DeliveryDriverTrip."Trip Counter");
                DeliveryTrip_l.Setrange("POS Terminal No.", Terminal);
                if DeliveryTrip_l.Find('-') then begin
                    repeat
                        TransHeader.RESET;
                        TransHeader.SETRANGE(TransHeader."Store No.", DeliveryTrip_l."Store No.");
                        TransHeader.SETRANGE(TransHeader."Receipt No.", DeliveryTrip_l."Order No.");
                        if TransHeader.FindFirst() then begin
                            PayEntry.RESET;
                            PayEntry.SETRANGE(PayEntry."Store No.", TransHeader."Store No.");
                            PayEntry.SETRANGE(PayEntry."Transaction No.", TransHeader."Transaction No.");
                            PayEntry.SetRange("POS Terminal No.", TransHeader."POS Terminal No.");
                            if PayEntry.FindFirst() then begin
                                repeat
                                    if (PayEntry."Tender Type" = '1') and (PayEntry."Change Line" = true) then begin
                                        if PosCashDecChanlTmp.Get('', PayEntry."Tender Type", PayEntry."Currency Code", PayEntry."Card No.") then begin
                                            PosCashDecChanlTmp."Trans. Amount" := PosCashDeclTmp."Trans. Amount" + PayEntry."Amount in Currency";
                                            PosCashDecChanlTmp.Modify;
                                        end else begin
                                            Clear(PosCashDecChanlTmp);
                                            PosCashDecChanlTmp."Tender Type" := PayEntry."Tender Type";
                                            PosCashDecChanlTmp."Currency Code" := PayEntry."Currency Code";
                                            PosCashDecChanlTmp."Card No." := PayEntry."Card No.";
                                            PosCashDecChanlTmp."Trans. Amount" := PayEntry."Amount in Currency";
                                            PosCashDecChanlTmp.Insert;
                                        end;
                                    end else
                                        if PosCashDeclTmp.Get('', PayEntry."Tender Type", PayEntry."Currency Code", PayEntry."Card No.") then begin
                                            PosCashDeclTmp."Trans. Amount" := PosCashDeclTmp."Trans. Amount" + PayEntry."Amount in Currency";
                                            PosCashDeclTmp.Modify;
                                        end
                                        else begin
                                            Clear(PosCashDeclTmp);
                                            PosCashDeclTmp."Tender Type" := PayEntry."Tender Type";
                                            PosCashDeclTmp."Currency Code" := PayEntry."Currency Code";
                                            PosCashDeclTmp."Card No." := PayEntry."Card No.";
                                            PosCashDeclTmp."Trans. Amount" := PayEntry."Amount in Currency";
                                            PosCashDeclTmp.Insert;
                                        end;
                                until PayEntry.Next() = 0;
                            end;
                        end;
                    until DeliveryTrip_l.Next = 0;
                end;
            until DeliveryDriverTrip.Next = 0;
        end;
    end;

    procedure CalcPaymentEntryO(PosTrans: Record "LSC POS Transaction"; var
                                                                            PosCashDeclTmp: Record "LSC POS Cash Declaration";
                                                                            Type: Integer)
    var
        PosStartStat: Record "LSC POS Start Status";
        PosCashDecl: Record "LSC POS Cash Declaration";
        PayEntry: Record "LSC Trans. Payment Entry";
        ErrorCode: Integer;
        CalcLocal: Boolean;
        InfocodeEntry: Record "LSC Trans. Infocode Entry";
    begin
        Store.Get(PosTrans."Store No.");
        PosFuncProfile.Get(Globals.FunctionalityProfileID);

        if Store."Statement Method" = Store."Statement Method"::Staff then begin
            //*********************************
            //* Staff
            //*********************************
            if not PosStartStat.Get(PosTrans."Store No.", PosStartStat.Type::Staff, PosTrans."Staff ID") then begin
                PosStartStat."Store No." := PosTrans."Store No.";
                PosStartStat.Type := PosStartStat.Type::Staff;
                PosStartStat.ID := PosTrans."Staff ID";
                PosStartStat."Next Tender Decl. ID" := '0000000001';
            end;

            CalcLocal := true;
            if PosFuncProfile."TS POS Cash Mgt." then begin
                if TSUtil.Initialize then begin
                    if TSUtil.CreateTmpTotalPayment(PosTrans, Type) then
                        if TSUtil.GetTotalPayment(PosStartStat, ErrorCode) then
                            if TSUtil.FirstTmpTotalPayment(PosCashDecl) then begin
                                CalcLocal := false;
                                repeat
                                    if PosCashDeclTmp.Get('', PosCashDecl."Tender Type", PosCashDecl."Currency Code", PosCashDecl."Card No.") then begin
                                        PosCashDeclTmp."Trans. Amount" := PosCashDeclTmp."Trans. Amount" + PosCashDecl."Trans. Amount";
                                        PosCashDeclTmp.Modify;
                                    end
                                    else begin
                                        Clear(PosCashDeclTmp);
                                        PosCashDeclTmp."Tender Type" := PosCashDecl."Tender Type";
                                        PosCashDeclTmp."Currency Code" := PosCashDecl."Currency Code";
                                        PosCashDeclTmp."Card No." := PosCashDecl."Card No.";
                                        PosCashDeclTmp."Trans. Amount" := PosCashDecl."Trans. Amount";
                                        PosCashDeclTmp.Insert;
                                    end;
                                until (TSUtil.NextTmpTotalPayment(PosCashDecl) = false);
                            end;
                end;
            end;

            if CalcLocal then begin
                Clear(PayEntry);
                PayEntry.SetCurrentKey("Staff ID", "Tender Decl. ID", "Tender Type", "Currency Code");
                PayEntry.SetRange("Staff ID", PosStartStat.ID);
                PayEntry.SetRange("Tender Decl. ID", PosStartStat."Next Tender Decl. ID");
                PayEntry.SetRange("Store No.", PosTrans."Store No.");
                if PayEntry.FindFirst then
                    repeat
                        if PosCashDeclTmp.Get('', PayEntry."Tender Type", PayEntry."Currency Code", PayEntry."Card No.") then begin
                            PosCashDeclTmp."Trans. Amount" := PosCashDeclTmp."Trans. Amount" + PayEntry."Amount in Currency";
                            PosCashDeclTmp.Modify;
                        end
                        else begin
                            Clear(PosCashDeclTmp);
                            PosCashDeclTmp."Tender Type" := PayEntry."Tender Type";
                            PosCashDeclTmp."Currency Code" := PayEntry."Currency Code";
                            PosCashDeclTmp."Card No." := PayEntry."Card No.";
                            PosCashDeclTmp."Trans. Amount" := PayEntry."Amount in Currency";
                            PosCashDeclTmp.Insert;
                        end;
                    until PayEntry.Next = 0;
            end;
        end
        else begin
            //*********************************
            //* POS Terminal
            //*********************************
            if not PosStartStat.Get(PosTrans."Store No.", PosStartStat.Type::"POS Terminal", PosTrans."POS Terminal No.") then begin
                PosStartStat."Store No." := PosTrans."Store No.";
                PosStartStat.Type := PosStartStat.Type::"POS Terminal";
                PosStartStat.ID := PosTrans."POS Terminal No.";
                PosStartStat."Next Tender Decl. ID" := '0000000001';
            end;
            Clear(PayEntry);
            PayEntry.SetCurrentKey("Tender Decl. ID", "Tender Type", "Currency Code");
            PayEntry.SetRange("Tender Decl. ID", PosStartStat."Next Tender Decl. ID");
            PayEntry.SetRange("Store No.", PosTrans."Store No.");
            PayEntry.SetRange("POS Terminal No.", PosTrans."POS Terminal No.");
            //PayEntry.SetRange("Change Line", true);
            if PayEntry.FindFirst then
                repeat
                    InfocodeEntry.Reset();
                    InfocodeEntry.SetRange("Transaction No.", PayEntry."Transaction No.");
                    InfocodeEntry.SetRange("Store No.", PayEntry."Store No.");
                    InfocodeEntry.SetRange("POS Terminal No.", PayEntry."POS Terminal No.");
                    InfocodeEntry.SetRange("Line No.", 60);
                    if InfocodeEntry.FindSet() then begin
                        if PosCashDeclTmp.Get('', PayEntry."Tender Type", PayEntry."Currency Code", PayEntry."Card No.") then begin
                            PosCashDeclTmp."Trans. Amount" := PosCashDeclTmp."Trans. Amount" + PayEntry."Amount in Currency";
                            PosCashDeclTmp.Modify;
                        end
                        else begin
                            Clear(PosCashDeclTmp);
                            PosCashDeclTmp."Tender Type" := PayEntry."Tender Type";
                            PosCashDeclTmp."Currency Code" := PayEntry."Currency Code";
                            PosCashDeclTmp."Card No." := PayEntry."Card No.";
                            PosCashDeclTmp."Trans. Amount" := PayEntry."Amount in Currency";
                            PosCashDeclTmp.Insert;
                        end;
                    end;
                until PayEntry.Next = 0;
        end;
    end;

    procedure CalcPaymentEntryChan(PosTrans: Record "LSC POS Transaction"; var PosCashDeclTmp: Record "LSC POS Cash Declaration"; Type: Integer)
    var
        PosStartStat: Record "LSC POS Start Status";
        PosCashDecl: Record "LSC POS Cash Declaration";
        PayEntry: Record "LSC Trans. Payment Entry";
        ErrorCode: Integer;
        CalcLocal: Boolean;
        InfocodeEntry: Record "LSC Trans. Infocode Entry";
    begin
        Store.Get(PosTrans."Store No.");
        PosFuncProfile.Get(Globals.FunctionalityProfileID);

        if Store."Statement Method" = Store."Statement Method"::Staff then begin
            //*********************************
            //* Staff
            //*********************************
            if not PosStartStat.Get(PosTrans."Store No.", PosStartStat.Type::Staff, PosTrans."Staff ID") then begin
                PosStartStat."Store No." := PosTrans."Store No.";
                PosStartStat.Type := PosStartStat.Type::Staff;
                PosStartStat.ID := PosTrans."Staff ID";
                PosStartStat."Next Tender Decl. ID" := '0000000001';
            end;

            CalcLocal := true;
            if PosFuncProfile."TS POS Cash Mgt." then begin
                if TSUtil.Initialize then begin
                    if TSUtil.CreateTmpTotalPayment(PosTrans, Type) then
                        if TSUtil.GetTotalPayment(PosStartStat, ErrorCode) then
                            if TSUtil.FirstTmpTotalPayment(PosCashDecl) then begin
                                CalcLocal := false;
                                repeat
                                    if PosCashDeclTmp.Get('', PosCashDecl."Tender Type", PosCashDecl."Currency Code", PosCashDecl."Card No.") then begin
                                        PosCashDeclTmp."Trans. Amount" := PosCashDeclTmp."Trans. Amount" + PosCashDecl."Trans. Amount";
                                        PosCashDeclTmp.Modify;
                                    end
                                    else begin
                                        Clear(PosCashDeclTmp);
                                        PosCashDeclTmp."Tender Type" := PosCashDecl."Tender Type";
                                        PosCashDeclTmp."Currency Code" := PosCashDecl."Currency Code";
                                        PosCashDeclTmp."Card No." := PosCashDecl."Card No.";
                                        PosCashDeclTmp."Trans. Amount" := PosCashDecl."Trans. Amount";
                                        PosCashDeclTmp.Insert;
                                    end;
                                until (TSUtil.NextTmpTotalPayment(PosCashDecl) = false);
                            end;
                end;
            end;

            if CalcLocal then begin
                Clear(PayEntry);
                PayEntry.SetCurrentKey("Staff ID", "Tender Decl. ID", "Tender Type", "Currency Code");
                PayEntry.SetRange("Staff ID", PosStartStat.ID);
                PayEntry.SetRange("Tender Decl. ID", PosStartStat."Next Tender Decl. ID");
                PayEntry.SetRange("Store No.", PosTrans."Store No.");
                if PayEntry.FindFirst then
                    repeat
                        if PosCashDeclTmp.Get('', PayEntry."Tender Type", PayEntry."Currency Code", PayEntry."Card No.") then begin
                            PosCashDeclTmp."Trans. Amount" := PosCashDeclTmp."Trans. Amount" + PayEntry."Amount in Currency";
                            PosCashDeclTmp.Modify;
                        end
                        else begin
                            Clear(PosCashDeclTmp);
                            PosCashDeclTmp."Tender Type" := PayEntry."Tender Type";
                            PosCashDeclTmp."Currency Code" := PayEntry."Currency Code";
                            PosCashDeclTmp."Card No." := PayEntry."Card No.";
                            PosCashDeclTmp."Trans. Amount" := PayEntry."Amount in Currency";
                            PosCashDeclTmp.Insert;
                        end;
                    until PayEntry.Next = 0;
            end;
        end
        else begin
            //*********************************
            //* POS Terminal
            //*********************************
            if not PosStartStat.Get(PosTrans."Store No.", PosStartStat.Type::"POS Terminal", PosTrans."POS Terminal No.") then begin
                PosStartStat."Store No." := PosTrans."Store No.";
                PosStartStat.Type := PosStartStat.Type::"POS Terminal";
                PosStartStat.ID := PosTrans."POS Terminal No.";
                PosStartStat."Next Tender Decl. ID" := '0000000001';
            end;
            Clear(PayEntry);
            PayEntry.SetCurrentKey("Tender Decl. ID", "Tender Type", "Currency Code");
            PayEntry.SetRange("Tender Decl. ID", PosStartStat."Next Tender Decl. ID");
            PayEntry.SetRange("Store No.", PosTrans."Store No.");
            PayEntry.SetRange("POS Terminal No.", PosTrans."POS Terminal No.");
            PayEntry.SetRange("Change Line", true);
            if PayEntry.FindSet then
                repeat
                    InfocodeEntry.Reset();
                    InfocodeEntry.SetRange("Transaction No.", PayEntry."Transaction No.");
                    InfocodeEntry.SetRange("Store No.", PayEntry."Store No.");
                    InfocodeEntry.SetRange("POS Terminal No.", PayEntry."POS Terminal No.");
                    InfocodeEntry.SetRange("Line No.", 60);
                    if InfocodeEntry.FindSet() then begin
                        if PosCashDeclTmp.Get('', PayEntry."Tender Type", PayEntry."Currency Code", PayEntry."Card No.") then begin
                            PosCashDeclTmp."Trans. Amount" := PosCashDeclTmp."Trans. Amount" + PayEntry."Amount in Currency";
                            PosCashDeclTmp.Modify;
                        end
                        else begin
                            Clear(PosCashDeclTmp);
                            PosCashDeclTmp."Tender Type" := PayEntry."Tender Type";
                            PosCashDeclTmp."Currency Code" := PayEntry."Currency Code";
                            PosCashDeclTmp."Card No." := PayEntry."Card No.";
                            PosCashDeclTmp."Trans. Amount" := PayEntry."Amount in Currency";
                            PosCashDeclTmp.Insert;
                        end;
                    end;
                until PayEntry.Next = 0;
        end;
    end;
}