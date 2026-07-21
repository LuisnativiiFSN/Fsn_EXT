/// <summary>
/// PageExtension FSN RetailReceiving (ID 50049) extends Record LSC Retail Receiving.
/// </summary>
pageextension 50049 "FSN RetailReceiving" extends "LSC Retail Receiving"
{
    layout
    {
        modify(Receiving)
        {
            Editable = EditableModify;
        }
        addafter(Status)
        {

            field("DTE Invoice"; Rec."DTE Invoice")
            {
                ApplicationArea = All;
                trigger OnLookup(var Text: Text): Boolean
                var
                    PHeader: Record "Purchase Header";
                    RPurchDte: Record "FSN Recep. Purch. DTE";
                    Vendor: Record Vendor;
                    Locations: Record Location;
                    Actional: Action;
                    VendorInvNumber: Integer;
                    pickingLine: Record "LSC Picking / Receiving lines";
                    ExtPurch: Codeunit "FSN External Purch. Manager";
                    convert: Text;
                    invoiceList: List of [Text];
                    invoice: Text;
                    util: Codeunit "FSN External Purch. Manager";
                    lTex001: Label 'La recepción debe tener al menos una linea antes de seleccionar DTE';
                    lTex002: Label 'Registro vendedor no tiene NIT';
                    lTex003: Label 'Este DTE ya fue registrado';
                    lText004: Label 'Pendiente Configuración Parametro Consulta Automatica DTE-> Grupo:CONFCOM Codigo:CONFDTECOM';
                    fsnParam: Record "FSN Parameter";
                    locationParameterList: List of [Text];
                    locationParameter: Text;

                begin

                    pickingLine.Reset();
                    pickingLine.SetRange("Document No.", Rec."No.");
                    if not pickingLine.FindFirst() then
                        Error(lTex001);
                    if pickingLine.FindFirst() then;
                    case Rec."Counting Type" of
                        Rec."Counting Type"::Receiving:
                            case Rec.Receiving of
                                Rec.Receiving::"Purchase Order":
                                    begin
                                        Vendor.Reset();
                                        Vendor.SetRange("No.", Rec."Vendor No. / Customer No.");
                                        if Vendor.FindFirst() then
                                            if Vendor."VAT Registration No." = '' then
                                                Error(lTex002);
                                        RPurchDte.Reset();
                                        RPurchDte.SetFilter("Issue Date", '>01/01/2025');
                                        RPurchDte.SetRange("Record Processed", false);
                                        RPurchDte.SetFilter("VAT Registration No.", '%1|%2', DelChr(Vendor."VAT Registration No.", '=', '-'), Vendor."VAT Registration No.");
                                        if PAGE.RunModal(PAGE::"FSN Recep. Purch. DTE", RPurchDte) = Action::LookupOK then begin
                                            if RPurchDte."Record Processed" then
                                                Error(lTex003);
                                            invoice := RPurchDte."DTE Invoice";
                                            if invoice.Contains('-') AND invoice.Contains('DTE') AND (invoice <> '') then begin
                                                invoiceList := invoice.Split('-');
                                                Rec.Validate("Vendor Invoice Number", DelChr((invoiceList.Get(invoiceList.Count)), '<', '0'));
                                                Rec.Validate("Vendor Invoice Serie", invoiceList.Get(1) + DelChr(invoiceList.Get(2), '=', '0'));
                                                Rec."DTE Invoice" := RPurchDte."DTE Invoice";
                                                Rec."DTE AuthNumber" := RPurchDte."DTE AuthNumber";
                                                Rec."Signature Validation" := RPurchDte."Signature Validation";
                                                Rec."Unique Document No." := Rec."Vendor Invoice No.";
                                                Rec."Vendor Invoice No." := Rec."Vendor Invoice Serie" + '-' + Rec."Vendor Invoice Number";
                                                IF strlen(Rec."Vendor Invoice No.") < 20 then
                                                    Rec."Vendor Invoice No." := Rec."Vendor Invoice Serie" + '-0' + Rec."Vendor Invoice Number";
                                                Rec.Modify(true);
                                                //Obtiene los costos de los DTE Json y actualiza el pedido
                                                //validar unicamente los almacenes por parametro de configuración fsn CONFDTECOM
                                                Clear(locationParameter);
                                                fsnParam.Reset();
                                                if fsnParam.Get('CONFCOM', 'CONFDTECOM') then begin
                                                    if fsnParam.Activo then begin
                                                        locationParameterList := fsnParam.Valor.Split('|');
                                                        foreach locationParameter in LocationParameterList do begin
                                                            if Rec."Location Code" = locationParameter then begin
                                                                if RPurchDte."DTE AuthNumber" <> '' then
                                                                    util.UpdatePurchLineCost(Rec, RPurchDte."DTE AuthNumber", false);
                                                                break;
                                                            end;
                                                        end;
                                                    end else
                                                        if RPurchDte."DTE AuthNumber" <> '' then
                                                            util.UpdatePurchLineCost(Rec, RPurchDte."DTE AuthNumber", false);
                                                end else
                                                    Error(lText004);
                                            end;
                                            //********************************************************
                                            CurrPage.Update(True);
                                        end;
                                    end;
                            end;
                    end;
                end;

                trigger OnValidate()
                var

                    invoiceList: List of [Text];
                    invoice: Text;
                    util: Codeunit "FSN External Purch. Manager";
                    RPurchDte: Record "FSN Recep. Purch. DTE";
                    Vendor: Record Vendor;
                    lTex001: Label 'La recepción debe tener al menos una linea antes de seleccionar DTE';
                    lTex002: Label 'Registro Proveedor no tiene NIT';
                    lTex003: Label 'Este DTE ya fue registrado';
                    lTex004: Label 'DTE no valido debe contener 31 caracteres incluyendo guiones: Ej DTE-03-M0010000-000000000000000';
                    lTex005: Label 'No se puede registrar la recepción del pedido con DTE de Mascara';
                    lTex006: Label 'Pendiente Configuración Parametro Consulta Automatica DTE-> Grupo:CONFCOM Codigo:CONFDTECOM';
                begin
                    if StrLen(Rec."DTE Invoice") = 31 then begin
                        if Rec."DTE Invoice" <> 'DTE-03-M0010000-000000000000000' then begin
                            Vendor.Reset();
                            Vendor.SetRange("No.", Rec."Vendor No. / Customer No.");
                            if Vendor.FindFirst() then
                                if Vendor."VAT Registration No." = '' then
                                    Error(lTex002);
                            RPurchDte.Reset();
                            RPurchDte.SetFilter("Issue Date", '>01/01/2025');
                            RPurchDte.SetFilter("VAT Registration No.", '%1|%2', DelChr(Vendor."VAT Registration No.", '=', '-'), Vendor."VAT Registration No.");
                            RPurchDte.SetRange("DTE Invoice", Rec."DTE Invoice");
                            if RPurchDte.FindFirst() then begin
                                if RPurchDte."Record Processed" then
                                    Error(lTex003);
                                invoice := RPurchDte."DTE Invoice";
                                if invoice.Contains('-') AND invoice.Contains('DTE') AND (invoice <> '') then begin
                                    invoiceList := invoice.Split('-');
                                    Rec.Validate("Vendor Invoice Number", DelChr((invoiceList.Get(invoiceList.Count)), '<', '0'));
                                    Rec.Validate("Vendor Invoice Serie", invoiceList.Get(1) + DelChr(invoiceList.Get(2), '=', '0'));
                                    Rec."DTE Invoice" := RPurchDte."DTE Invoice";
                                    Rec."DTE AuthNumber" := RPurchDte."DTE AuthNumber";
                                    Rec."Signature Validation" := RPurchDte."Signature Validation";
                                    Rec."Unique Document No." := Rec."Vendor Invoice No.";
                                    Rec.Modify(true);
                                    CurrPage.Update(true);
                                end;
                            end else begin
                                invoice := Rec."DTE Invoice";
                                if invoice.Contains('-') AND invoice.Contains('DTE') AND (invoice <> '') then begin
                                    invoiceList := invoice.Split('-');
                                    Rec.Validate("Vendor Invoice Number", DelChr((invoiceList.Get(invoiceList.Count)), '<', '0'));
                                    Rec.Validate("Vendor Invoice Serie", invoiceList.Get(1) + DelChr(invoiceList.Get(2), '=', '0'));
                                    Rec."Unique Document No." := invoice;
                                    Rec.Modify(true);
                                    CurrPage.Update(true);
                                end;
                            end;
                        end else
                            Error(lTex005);
                    end else
                        Error(lTex004);
                end;
            }
            field("DTE AuthNumber"; Rec."DTE AuthNumber")
            {
                ApplicationArea = All;
            }
            field("Signature Validation"; Rec."Signature Validation")
            {
                ApplicationArea = All;
            }
            field("MovRetundOption"; Rec."FSN Reason Option")
            {
                ApplicationArea = All;
                Caption = 'Motivo de Rechazo';
                trigger OnValidate()
                var
                    myInt: Integer;
                begin
                    if ("FSN Reason Option" = "FSN Reason Option"::Otros) or ("FSN Reason Option" = "FSN Reason Option"::Courier) then
                        ViewReasonText := true
                    else
                        ViewReasonText := false;

                end;
            }

            field("MovText"; "FSN Reason")
            {
                Caption = 'Descripcion de Rechazo';
                ApplicationArea = All;
                Editable = ViewReasonText;
            }
        }
        addafter("Vendor Invoice No.")
        {
            field("No. Credit Memo Associated"; "No. Credit Memo Associated")
            {

                ApplicationArea = All;

            }
        }

        addafter("No. Credit Memo Associated")
        {
            field("FSN Status"; "FSN Status")
            {
                ApplicationArea = All;
                Editable = false;
                StyleExpr = StyleStatusText;

            }
            field("FSN Authorized Reception"; "FSN Authorized Reception")
            {
                ApplicationArea = All;
                trigger OnValidate()
                var
                    extPurchaseMan: Codeunit "FSN External Purch. Manager";
                    Text001: Label '¿Seguro que desea Cerrar la Recepción?';
                    Text002: Label 'La recepción no se puede reabrir';
                    fsnParam: Record "FSN Parameter";
                    parameterList: List of [Text];
                    parameterValue: Text;
                    paRetailR: Page "LSC Retail Receiving";
                    PRConfirm: Codeunit "LSC Picking/Receiving Confirm";
                begin
                    if Rec."FSN Authorized Reception" then begin
                        Rec."FSN Authorized Reception" := false;
                        Rec.Modify();
                        CurrPage.Update(true);
                        extPurchaseMan.ValReceipt(Rec."No.");
                        PRConfirm.Run(Rec);
                        if Confirm(Text001) then begin
                            CurrPage.Update(true);
                            Rec."FSN Authorized Reception" := true;
                            //PurchaseV66 Mod Field Date after Authorized
                            Rec."FSN Date Authorized" := System.CreateDateTime(Today(), Time());
                            Rec.Modify();
                            //paRetailR.SetRecord(Rec);
                            CurrPage.Close();
                            //paRetailR.Editable := false;
                            //paRetailR.Run();
                            //CurrPage.Editable := false;
                            //CurrPage.Update(true);
                        end else begin
                            Rec."FSN Authorized Reception" := false;
                            Rec.Modify();
                            CurrPage.Update(true);
                        end;
                    end;
                end;
            }
            field("FSN Date Authorized"; "FSN Date Authorized")
            {
                ApplicationArea = All;
                Editable = false;
            }
        }

        modify("Vendor Invoice Serie")
        {
            ApplicationArea = All;
            Editable = NOT Rec."FSN Automatic Search";
        }
        modify("Vendor Invoice Number")
        {
            ApplicationArea = All;
            Editable = NOT Rec."FSN Automatic Search";
        }
        modify("Unique Document No.")
        {
            ApplicationArea = All;
            Editable = NOT Rec."FSN Automatic Search";
        }
    }

    actions
    {
        addafter(Post)
        {
            action(Scanner)
            {
                ApplicationArea = All;
                Caption = 'Scanner';
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                Image = BarCode;
                Enabled = EditableModify;

                trigger OnAction()
                var
                    PageScanner: Page "FSN Purch. Receipt by Scanner";
                    PRLines: Record "LSC Picking / Receiving lines";
                begin
                    Clear(PageScanner);
                    //PRLines.Reset();
                    //PRLines.SetRange("Document No.", Rec."No.");
                    ///PRLines.SetFilter(Quantity, '>%1', 0);
                    //PRLines.SetRange("FSN Escaneo Pendiente", true);
                    //if PRLines.FindFirst() then begin
                    //PageScanner.SetPurchOrderNo(Rec."No.", true)
                    //else
                    PageScanner.SetPurchOrderNo(Rec."No.", false);
                    PageScanner.RunModal();
                    //end else
                    //Error(Text004);
                end;
            }

            action(MascaraDte)
            {
                ApplicationArea = All;
                Caption = 'Usar Mascara DTE';
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                Image = ImportCodes;
                Enabled = EditableModify;
                trigger OnAction()
                var
                    Text001: Label 'Para el proveedor %1 solo se permite registrar recepción por medio DTE';
                begin
                    if Rec."FSN Automatic Search" then
                        Message(Text001, Rec."Vendor No. / Customer No.")
                    else
                        Rec."DTE Invoice" := 'DTE-03-00000000-000000000000000';
                end;
            }

            action(ReportDiffReceipt)
            {
                ApplicationArea = All;
                Caption = 'Report Difference Receipt';
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Report;
                Image = BankAccountRec;
                trigger OnAction()
                var
                    recReport: Record "Purchase Header";
                begin
                    recReport.reset();
                    //recReport.SetRange("Reference No.", Rec."Reference No.");
                    //recReport.SetRange("FSN Authorized Reception", true);
                    recReport.SetFilter("No.", '%1', Rec."Reference No.");
                    if recReport.FindFirst() then
                        Report.Run(50081, true, false, recReport);
                end;
            }

            action(FSNPostAndPrint)
            {
                ApplicationArea = all;
                Caption = 'Aplicar por Lotes';
                Image = AddAction;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ShortCutKey = 'Shift+F9';
                ToolTip = 'Marcar como AplicandoAutomatico';

                trigger OnAction()
                var
                    Text004: Label 'El campo %1 no puede ser cero o estar vacio';
                    Text008: Label 'No se puede registrar el pedido con DTE de Mascara';
                    PurchHeader: Record "Purchase Header";
                    PurchLine: Record "Purchase Line";
                    FSNExtPurhMng: Codeunit "FSN External Purch. Manager";
                    MessageLogResul: Text;
                begin
                    Rec.TestField("Counted Date");//28981
                    if Rec.Receiving = Rec.Receiving::"Purchase Order" then
                        FSNExtPurhMng.ValReceipt(Rec."No.");

                    IF CONFIRM('¿Desea aplicar la recepcion? \->Si acepta, el sistema lo aplicará lo mas pronto posible.') THEN BEGIN
                        IF Rec."FSN Status" = Rec."FSN Status"::AplicandoAutomatico THEN
                            EXIT;
                        Rec."FSN Status" := Rec."FSN Status"::AplicandoAutomatico;
                        Rec.MODIFY;
                        EXIT;
                    END;
                end;
            }

            action("Purchase returned")
            {
                ApplicationArea = All;
                Caption = 'Compra Rechazada';
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                Image = CancelIndent;
                Enabled = EditableModify;
                trigger OnAction()
                var
                    Textselect: Label 'Dev. partially,Closed';
                    StatusPost: Integer;
                    PurchaseHeader: Record "Purchase Header";
                    Text000: Label 'Motivo de Rechazo no puede ser NONE';
                    Text001: Label 'Registro Proveedor no tiene NIT';
                    RPurchDte: Record "FSN Recep. Purch. DTE";
                    Vendor: Record Vendor;
                begin
                    PurchaseHeader.Reset();
                    PurchaseHeader.SetCurrentKey("Document Type", "No.");
                    PurchaseHeader.SetRange(PurchaseHeader."Document Type", PurchaseHeader."Document Type"::Order);
                    PurchaseHeader.SetRange(PurchaseHeader."No.", Rec."Reference No.");
                    if PurchaseHeader.FindFirst() then begin
                        StatusPost := StrMenu(Textselect, 2);//28981

                        if "FSN Reason Option" = "FSN Reason Option"::None then
                            Error(Text000);

                        if StatusPost <> 0 then
                            SendCreateExternalLines(PurchaseHeader, StatusPost);

                        //Ver1.0.0.62-JH1 Deshabilitar el DTE cuando se rechaza la recepción
                        if Rec."DTE Invoice" <> '' then begin
                            Vendor.Reset();
                            Vendor.SetRange("No.", Rec."Vendor No. / Customer No.");
                            if Vendor.FindFirst() then
                                if Vendor."VAT Registration No." = '' then
                                    Error(Text001);
                            RPurchDte.Reset();
                            RPurchDte.SetFilter("Issue Date", '>01/01/2025');
                            RPurchDte.SetFilter("VAT Registration No.", '%1|%2', DelChr(Vendor."VAT Registration No.", '=', '-'), Vendor."VAT Registration No.");
                            RPurchDte.SetRange("DTE Invoice", Rec."DTE Invoice");
                            if RPurchDte.FindFirst() then
                                repeat
                                    if not RPurchDte."Record Processed" then begin
                                        RPurchDte."Record Processed" := true;
                                        RPurchDte.Modify();
                                    end;
                                until RPurchDte.Next() = 0;
                        end;
                        //Ver1.0.0.62-JH1********************************************
                    end;
                end;
            }
        }
    }
    var
        Scanner: Code[20];
        subTotal, vat, Total : Decimal;
        Text001: Label 'Limite para el calculo manual de IVA es (más o menos) $0.10';
        Text002: Label 'Limite para el calculo manual de Subtotal es (más o menos) $1.00';
        Text003: Label 'El producto %1 no tiene unidad de medida';
        Text004: Label 'Hay lineas pendientes de escanear';
        ViewReasonText: Boolean;
        NoCredMemoVisible: Boolean;
        NoCredMemoRequired: Boolean;
        StyleStatusText: Text;
        StyleStatus: Option None,Standard,StandardAccent,Strong,StrongAccent,Attention,AttentionAccent,Favorable,Unfavorable,Ambiguous,Subordinate;
        EditableModify: Boolean;
    #region Triggers

    trigger OnAfterGetRecord()
    begin
        EditableModify := true;
        OnValidateFSNClosedReception;
        if Rec."FSN Authorized Reception" then
            EditableModify := false;
        ValStyle();
        CalculateTotals(Rec);
        OnValidateVendorIssueDTE;
    end;

    trigger OnModifyRecord(): Boolean
    begin
        EditableModify := true;
        OnValidateFSNClosedReception;
        if Rec."FSN Authorized Reception" then
            EditableModify := false;
        ValStyle();
        CalculateTotals(Rec);
        onValidateVendorIssueDTE;

    end;

    trigger OnDeleteRecord(): Boolean
    begin

    end;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        Rec."Vendor Invoice No." := '';
        Rec."Vendor Invoice Serie" := '';
        Rec."Vendor Invoice Number" := '';
        Rec."DTE AuthNumber" := '';
        Rec."Signature Validation" := '';
        Rec."DTE Invoice" := '';
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var
    begin
    end;

    trigger OnOpenPage()
    var
    begin
        EditableModify := true;
        OnValidateFSNClosedReception;
        if Rec."FSN Authorized Reception" then
            EditableModify := false;
        ValStyle();
        if "FSN Reason Option" = "FSN Reason Option"::Otros then
            ViewReasonText := true
        else
            ViewReasonText := false;
    end;

    #endregion Triggers
    local procedure CalculateTotals(var PRHeader: Record "LSC P/R Counting Header")
    var
        PRLines: Record "LSC Picking / Receiving lines";
        purchaseLine: Record "Purchase Line";
        subTotalBase, vatBase, TotalBase : Decimal;
        IUM: Record "Item Unit of Measure";
    begin
        //Se traslada el Calculo total a Lineas
        //if not PRHeader.Get(Rec."No.") then
        //    exit;
        //Clear(subTotal);
        //Clear(vat);
        //Clear(Total);

        if PRHeader."Withhold ISR No." = '' then
            PRHeader."Withhold ISR No." := '0';
        if PRHeader."Withhold Tax No." = '' then
            PRHeader."Withhold Tax No." := '0';
        /*
            PRLines.Reset();
            PRLines.SetRange("Document No.", Rec."No.");
            PRLines.SetFilter(Quantity, '>%1', 0);
            if PRLines.FindSet() then
                repeat
                    purchaseLine.Reset();
                    purchaseLine.SetRange("Document No.", PRHeader."Reference No.");
                    purchaseLine.SetRange("No.", PRLines."Item No.");
                    if purchaseLine.FindFirst() then begin
                        if IUM.Get(purchaseLine."No.", purchaseLine."Unit of Measure Code") then begin
                            if PRLines."Unit of Measure Code" <> purchaseLine."Unit of Measure Code" then begin
                                TotalBase += purchaseLine."Direct Unit Cost" * (PRLines.Quantity / IUM."Qty. per Unit of Measure") + ((purchaseLine."Direct Unit Cost" * (PRLines.Quantity / IUM."Qty. per Unit of Measure")) * (purchaseLine."VAT %" / 100));
                                subTotalBase += purchaseLine."Direct Unit Cost" * (PRLines.Quantity / IUM."Qty. per Unit of Measure");
                                vatBase += ((purchaseLine."Direct Unit Cost" * (PRLines.Quantity / IUM."Qty. per Unit of Measure")) * (purchaseLine."VAT %" / 100));
                            end else begin
                                TotalBase += purchaseLine."Direct Unit Cost" * (PRLines.Quantity) + ((purchaseLine."Direct Unit Cost" * (PRLines.Quantity)) * (purchaseLine."VAT %" / 100));
                                subTotalBase += purchaseLine."Direct Unit Cost" * (PRLines.Quantity);
                                vatBase += ((purchaseLine."Direct Unit Cost" * (PRLines.Quantity)) * (purchaseLine."VAT %" / 100));
                            end;

                        end else
                            Error(Text003, purchaseLine."No.");
                    end;
                until PRLines.Next = 0;
            if ((Round(PRHeader.Total, 0.001, '=') - Round(TotalBase, 0.001, '=')) <> 0) or ((Round(PRHeader.Tax, 0.001, '=') - Round(vatBase, 0.001, '=')) <> 0) or ((Round(PRHeader.SubTotal, 0.001, '=') - Round(subTotalBase, 0.001, '=')) <> 0) then begin
                if ((PRHeader.Total - TotalBase) > 1.0) OR ((TotalBase - PRHeader.Total) > 1.0) then begin
                    subTotal := subTotalBase;
                    vat := vatBase;
                    Total := TotalBase;

                    PRHeader."Subtotal" := subTotalBase;
                    PRHeader."Tax" := vatBase;
                    PRHeader."Total" := TotalBase;
                    PRHeader.Modify();
                    Commit();
                end else begin
                    subTotal := PRHeader."Subtotal";
                    vat := PRHeader."Tax";
                    Total := PRHeader."Total";
                end;
            end else begin
                subTotal := PRHeader."Subtotal";
                vat := PRHeader."Tax";
                Total := PRHeader."Total";
            end;
        */
    end;

    local procedure CalsTotalsModManual(var PRHeader: Record "LSC P/R Counting Header")
    var
        PRLines: Record "LSC Picking / Receiving lines";
        subTotalBase, vatBase : Decimal;
        purchaseLine: Record "Purchase Line";
        IUM: Record "Item Unit of Measure";
    begin

        //if not PRHeader.Get(Rec."No.") then
        //    exit;
        PRLines.Reset();
        PRLines.SetRange("Document No.", Rec."No.");
        PRLines.SetFilter(Quantity, '>%1', 0);
        if PRLines.FindSet() then
            repeat
                purchaseLine.Reset();
                purchaseLine.SetRange("Document No.", PRHeader."Reference No.");
                purchaseLine.SetRange("No.", PRLines."Item No.");
                if purchaseLine.FindFirst() then begin
                    if IUM.Get(purchaseLine."No.", purchaseLine."Unit of Measure Code") then begin
                        if PRLines."Unit of Measure Code" <> purchaseLine."Unit of Measure Code" then begin
                            subTotalBase += purchaseLine."Direct Unit Cost" * (PRLines.Quantity / PRLines."Qty. per Unit of Measure");
                            vatBase += ((purchaseLine."Direct Unit Cost" * (PRLines.Quantity / PRLines."Qty. per Unit of Measure")) * (purchaseLine."VAT %" / 100));
                        end else begin
                            subTotalBase += purchaseLine."Direct Unit Cost" * (PRLines.Quantity);
                            vatBase += ((purchaseLine."Direct Unit Cost" * (PRLines.Quantity)) * (purchaseLine."VAT %" / 100));
                        end;
                    end else
                        Error(Text003, purchaseLine."No.");
                end;
            until PRLines.Next = 0;

        if vat > vatBase then begin
            if (vat - vatBase) > 0.10 then begin
                Error(Text001);
            end;
        end else begin
            if (vatBase - vat) > 0.10 then begin
                Error(Text001);
            end;
        end;
        if subTotal > subTotalBase then begin
            if (subTotal - subTotalBase) > 1.0 then begin
                Error(Text002);
            end;
        end else begin
            if (subTotalBase - subTotal) > 1.0 then begin
                Error(Text002);
            end;
        end;

        PRHeader."Subtotal" := subTotal;
        PRHeader."Tax" := vat;
        PRHeader."Total" := Total;
        PRHeader.Modify();
        Commit();

    end;

    procedure SendCreateExternalLines(PurchaseHeader: Record "Purchase Header"; int: Integer)
    var
        Text000: Label 'Detalle del pedido %1 agregados como rechazado.';
        Text001: Label 'Debe confirmar el pedido.';
        Text002: Label 'Debe haber almenos un producto confirmado y escaneado para Pedido Rechazado Parcial.';
        PickRecepLine: Record "LSC Picking / Receiving lines";
    begin

        PickRecepLine.Reset();
        PickRecepLine.SetCurrentKey("Document No.", "Line No.");
        PickRecepLine.SetRange("Document No.", "No.");
        if int = 1 then
            PickRecepLine.SetFilter(Quantity, '<>%1', 0);
        if PickRecepLine.Find('-') then begin
            SendCreateExternalHeader(PurchaseHeader);
            repeat
                InsertPurchaseLine(PurchaseHeader, PickRecepLine."Line No.", int);
            until PickRecepLine.Next() = 0;
        end else begin
            if int = 1 then
                Error(Text002)
            else begin
                SendCreateExternalHeader(PurchaseHeader);
                InsertPurchaseLine(PurchaseHeader, 0, int);
            end;
        end;

    end;

    procedure InsertPurchaseLine(PurchaseHeader: Record "Purchase Header"; Line: Integer; TypeValue: Integer)
    var
        ExternalPurchLine: Record "FSN External Purch. Line";
        PurchaseLine: Record "Purchase Line";
        PurchaseLine2: Record "Purchase Line";
        ItemREC: Record Item;
        Vendor_l: Record Vendor;
        FSNBatchData: Codeunit "FSN Batch - Send Purchase Data";
    begin
        PurchaseLine.RESET;
        PurchaseLine.SETCURRENTKEY(PurchaseLine."No.", PurchaseLine."Line No.");
        PurchaseLine.SETRANGE(PurchaseLine."Document No.", PurchaseHeader."No.");
        if TypeValue = 1 then
            PurchaseLine.SETRANGE(PurchaseLine."Line No.", Line);
        IF PurchaseLine.Find('-') THEN
            repeat
                IF NOT ExternalPurchLine.GET(PurchaseLine."Document No.", PurchaseLine."Line No.") THEN BEGIN
                    ExternalPurchLine.INIT;
                    ExternalPurchLine."No." := PurchaseLine."Document No.";
                    ExternalPurchLine."Line No." := PurchaseLine."Line No.";
                    ExternalPurchLine."Starting Date" := CURRENTDATETIME;
                    ExternalPurchLine."Location Code" := PurchaseHeader."Location Code";

                    IF NOT GUIALLOWED THEN
                        IF PurchaseLine."Location Code" = '' THEN
                            IF PurchaseLine2.GET(PurchaseLine."Document Type", PurchaseLine."Document No.", PurchaseLine."Line No.") THEN BEGIN
                                PurchaseLine2."Location Code" := PurchaseHeader."Location Code";
                                PurchaseLine2.MODIFY;
                            END;

                    ExternalPurchLine."Source No." := PurchaseHeader."No.";
                    IF Vendor_l.GET(PurchaseHeader."Buy-from Vendor No.") THEN
                        if Vendor_l."FSN Code Vendor" <> '' then
                            ExternalPurchLine."Vendor No." := Vendor_l."FSN Code Vendor"
                        else
                            ExternalPurchLine."Vendor No." := PurchaseHeader."Buy-from Vendor No.";

                    if ExternalPurchLine."Vendor No." = '' then
                        if Vendor_l.Get(PurchaseLine."Buy-from Vendor No.") then
                            ExternalPurchLine."Vendor No." := Vendor_l."FSN Code Vendor";

                    ExternalPurchLine."Vendor Name" := CopyStr(PurchaseHeader."Buy-from Vendor Name", 1, 50);
                    ExternalPurchLine."Vendor Invoice No." := '';
                    ExternalPurchLine."Item No." := PurchaseLine."No.";
                    IF ItemREC.GET(PurchaseLine."No.") THEN
                        ExternalPurchLine."Barcode No." := ItemREC."FSN Barcode No.";
                    ExternalPurchLine.Description := CopyStr(PurchaseLine.Description, 1, 50);
                    ExternalPurchLine.Quantity := PurchaseLine.Quantity;
                    ExternalPurchLine."Qty. to Receive" := 0;
                    ExternalPurchLine."Unit of Measure" := PurchaseLine."Unit of Measure Code";
                    ExternalPurchLine."Direct Unit Cost" := FSNBatchData.FindDirectUnitCost(PurchaseLine."No.", PurchaseLine."Variant Code",
                      PurchaseLine."Unit of Measure Code", PurchaseHeader."Buy-from Vendor No.", PurchaseLine.Quantity);  //WVILLALTA05ABR19-+
                    IF ExternalPurchLine."Direct Unit Cost" = 0 THEN
                        ExternalPurchLine."Direct Unit Cost" := PurchaseLine."Direct Unit Cost";
                    ExternalPurchLine.Amount := PurchaseLine.Amount;
                    if "FSN Reason Option" = "FSN Reason Option"::Otros then
                        ExternalPurchLine.Description := Format("FSN Reason Option") + '-' + "FSN Reason"
                    else
                        ExternalPurchLine.Description := Format("FSN Reason Option");
                    ExternalPurchLine."Amount Including VAT" := PurchaseLine."Amount Including VAT";
                    ExternalPurchLine.Received := FALSE;
                    ExternalPurchLine.TransferComplete := FALSE;
                    ExternalPurchLine."Consolidado No." := PurchaseHeader."FSN Consolidate No.";
                    ExternalPurchLine.Rapidito := (PurchaseHeader."LSC Retail Purch Src Filter" = PurchaseHeader."LSC Retail Purch Src Filter"::" ");
                    ExternalPurchLine."Status Purchase" := ExternalPurchLine."Status Purchase"::returned;
                    ExternalPurchLine.INSERT(TRUE);
                END else begin
                    ExternalPurchLine."Status Purchase" := ExternalPurchLine."Status Purchase"::returned;
                    if "FSN Reason Option" = "FSN Reason Option"::Otros then
                        ExternalPurchLine.Description := Format("FSN Reason Option") + '-' + "FSN Reason"
                    else
                        ExternalPurchLine.Description := Format("FSN Reason Option");
                    ExternalPurchLine.Modify(TRUE);
                end;
            until PurchaseLine.Next() = 0;
    end;

    procedure SendCreateExternalHeader(PurchaseHeader: Record "Purchase Header")
    var
        ExternalPurchLine: Record "FSN External Purch. Line";
        ItemREC: Record Item;
        Vendor_l: Record Vendor;
        FSNBatchData: Codeunit "FSN Batch - Send Purchase Data";
        AmountVal: Decimal;
        AmountInclVATVal: Decimal;
        Text000: Label 'El pedido %1 ya se encuentra agregado.';
        Text001: Label 'Pedido Rechazado %1.';
    begin
        IF NOT ExternalPurchLine.GET(PurchaseHeader."No.", -10000) THEN BEGIN
            ExternalPurchLine.INIT;
            ExternalPurchLine."No." := PurchaseHeader."No.";
            ExternalPurchLine."Line No." := -10000;
            ExternalPurchLine."Starting Date" := CURRENTDATETIME;
            ExternalPurchLine."Location Code" := PurchaseHeader."Location Code";

            ExternalPurchLine."Source No." := PurchaseHeader."No.";
            IF Vendor_l.GET(PurchaseHeader."Buy-from Vendor No.") THEN
                if Vendor_l."FSN Code Vendor" <> '' then
                    ExternalPurchLine."Vendor No." := Vendor_l."FSN Code Vendor"
                else
                    ExternalPurchLine."Vendor No." := PurchaseHeader."Buy-from Vendor No.";

            if ExternalPurchLine."Vendor No." = '' then
                if Vendor_l.Get(PurchaseHeader."Buy-from Vendor No.") then
                    ExternalPurchLine."Vendor No." := Vendor_l."FSN Code Vendor";

            ExternalPurchLine."Vendor Name" := CopyStr(PurchaseHeader."Buy-from Vendor Name", 1, 50);
            ExternalPurchLine."Vendor Invoice No." := '';
            ExternalPurchLine."Qty. to Receive" := 0;
            if "FSN Reason Option" = "FSN Reason Option"::Otros then
                ExternalPurchLine.Description := Format("FSN Reason Option") + '-' + "FSN Reason"
            else
                ExternalPurchLine.Description := Format("FSN Reason Option");
            SendCreateExternaConsolidate(PurchaseHeader, AmountVal, AmountInclVATVal);
            ExternalPurchLine.Amount := AmountVal;
            ExternalPurchLine."Amount Including VAT" := AmountInclVATVal;
            ExternalPurchLine.Received := FALSE;
            ExternalPurchLine.TransferComplete := FALSE;
            ExternalPurchLine."Consolidado No." := PurchaseHeader."FSN Consolidate No.";
            ExternalPurchLine.Rapidito := (PurchaseHeader."LSC Retail Purch Src Filter" = PurchaseHeader."LSC Retail Purch Src Filter"::" ");
            ExternalPurchLine."Status Purchase" := ExternalPurchLine."Status Purchase"::returned;
            ExternalPurchLine.INSERT(TRUE);
        END ELSE begin
            ExternalPurchLine."Status Purchase" := ExternalPurchLine."Status Purchase"::returned;
            if "FSN Reason Option" = "FSN Reason Option"::Otros then
                ExternalPurchLine.Description := Format("FSN Reason Option") + '-' + "FSN Reason"
            else
                ExternalPurchLine.Description := Format("FSN Reason Option");
            ExternalPurchLine.Modify(true);
        end;

    end;

    procedure SendCreateExternaConsolidate(PurchaseHeader: Record "Purchase Header"; var AmountV: Decimal; var AmountInclVATV: Decimal)
    var
        ExternalPurchLine: Record "FSN External Purch. Line";
        ItemREC: Record Item;
        PurchaseLine2: Record "Purchase Line";
        PurchaseLine: Record "Purchase Line";
        Vendor_l: Record Vendor;
        FSNBatchData: Codeunit "FSN Batch - Send Purchase Data";
    begin
        PurchaseLine.RESET;
        PurchaseLine.SETCURRENTKEY(PurchaseLine."No.", PurchaseLine."Line No.");
        PurchaseLine.SETRANGE(PurchaseLine."Document No.", PurchaseHeader."No.");
        IF PurchaseLine.FINDSET THEN
            REPEAT
                AmountV := AmountV + PurchaseLine.Amount;
                AmountInclVATV := AmountInclVATV + PurchaseLine."Amount Including VAT";
            UNTIL PurchaseLine.NEXT = 0;
    end;

    procedure ValStyle()
    begin
        if Rec."FSN Status" = Rec."FSN Status"::AplicandoAutomatico then
            StyleStatusText := Format(StyleStatus::StrongAccent)
        else
            StyleStatusText := Format(StyleStatus::None)
    end;

    procedure OnValidateFSNClosedReception()
    var
        extPurchaseMan: Codeunit "FSN External Purch. Manager";
        Text001: Label '¿Seguro que desea Cerrar la Recepción?';
        Text002: Label 'La recepción no se puede reabrir';
        fsnParam: Record "FSN Parameter";
        parameterList: List of [Text];
        parameterValue: Text;
    begin
        if Rec."FSN Authorized Reception" then begin
            fsnParam.Reset();
            if fsnParam.Get('CONFCOM', 'CONFCLRCOM') then begin
                if fsnParam.Activo then begin
                    parameterList := fsnParam.Valor.Split('|');
                    foreach parameterValue in parameterList do begin
                        if Rec."No." = parameterValue then begin
                            CurrPage.Editable := true;
                            Rec."FSN Authorized Reception" := false;
                        end;
                    end;
                end else
                    CurrPage.Editable := false;
            end;
        end else
            CurrPage.Editable := true;
    end;

    procedure OnValidateVendorIssueDTE()
    var
        Vendor: Record Vendor;
    begin
        Vendor.Reset();
        Rec."FSN Automatic Search" := Vendor.Get(Rec."Vendor No. / Customer No.") AND Vendor."DTE Issue";

    end;

}