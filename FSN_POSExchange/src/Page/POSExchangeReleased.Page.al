page 50037 "FSN POS Exchange Released"
{

    Caption = 'FSN POS Exchange Released';
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = true;
    PageType = List;
    PromotedActionCategories = 'Admin,Procesos,Documents';
    SourceTable = "FSN POS Exchange Transaction";
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Receipt No."; "Receipt No.")
                {
                    Editable = false;
                }
                field("Transaction No."; "Transaction No.")
                {
                    Editable = false;
                }
                field("Line No."; "Line No.")
                {
                    Editable = false;
                }
                field("Barcode No."; "Barcode No.")
                {
                    Editable = false;
                }
                field("Item No."; "Item No.")
                {
                    Editable = false;
                }
                field("Unit of Measure"; "Unit of Measure")
                {
                    Editable = false;
                }
                field(Description; GetItemDescription("Item No."))
                {
                    Caption = 'Description';
                }
                field(Quantity; Quantity)
                {
                    Editable = false;
                    Style = Strong;
                    StyleExpr = TRUE;
                }
                field(Request; Request)
                {
                    Editable = false;
                    StyleExpr = SetStyleTextRequire;
                }
                field(Status; Status)
                {
                    Editable = false;
                    OptionCaption = 'Open,Released,Send,Created Request,Confirmed Request,Exit Applied,Liquidating Product...,Liquidating CreditNote...,Void,Request Liquidate CN';
                    StyleExpr = SetStyleText;
                }
                field("Autorization Type"; "Autorization Type")
                {
                }
                field(ItemAtribute; "Attrib 1 Code")
                {
                    Caption = 'Item Attribute';
                    Enabled = false;
                }
                field(VendorName; ItemPrimaryVendor)
                {
                    Caption = 'Vendor Name';
                }
                field("Unit Cost"; "Unit Cost")
                {
                }
                field(CostAmount; CostAmount)
                {
                    Caption = 'CostAmount';
                }
                field("Store No."; "Store No.")
                {
                    Editable = false;
                }
                field("POS Terminal No."; "POS Terminal No.")
                {
                    Editable = false;
                }
                field("Transfer Order No."; "Transfer Order No.")
                {
                    Editable = false;
                }
                field("Staff ID"; "Staff ID")
                {
                    Editable = false;
                }
                field("Sales Staff"; "Sales Staff")
                {
                    Editable = false;
                }
                field("Customer No."; "Customer No.")
                {
                    Editable = false;
                }
                field("Transaction Date"; "Transaction Date")
                {
                    Editable = false;
                }
                field("POS Exchange No."; "POS Exchange No.")
                {
                    Editable = false;
                }
                field("Use Inventory"; "Use Inventory")
                {
                    Editable = false;
                }
                field(Complete; Complete)
                {
                    Editable = false;
                }
                field("Process Message"; "Process Message")
                {
                    Editable = false;
                }
                field("External Document No."; "External Document No.")
                {
                    Caption = 'External Document No.';
                    Editable = false;
                }
                field("Amount Doc. Inc. VAT"; "Amount Doc. Inc. VAT")
                {
                    Editable = false;
                }
                field("Vendor Document No."; "Vendor Document No.")
                {
                    Caption = 'Vendor Document No.';
                    Editable = false;
                }
                field("Transfer-to Code"; "Transfer-to Code")
                {
                    Editable = false;
                }
                field("Web Authorization No."; "Web Authorization No.")
                {
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            group(General)
            {
                action("Liquidate With Product")
                {
                    Caption = 'Liquidate With Product';
                    Image = ItemSubstitution;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;

                    trigger OnAction()
                    var
                        POSExchangeTrans_l: Record "FSN POS Exchange Transaction";
                        lText001: Label 'Liquidation Successfull. Product %1 Location %2';
                        lText002: Label 'Cant be liquidate in status %1';
                        LiquidatePageCard: Page "FSN Liquidate Exch. Document";
                    begin

                        LiquidatePageCard.SetTemporaryRecord(Rec, TRUE);
                        LiquidatePageCard.RUN;

                    end;
                }
                action("Liquidate With Credit Note")
                {
                    Caption = 'Liquidate With Credit Note';
                    Image = GetEntries;
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    var
                        MenuOffset: Integer;
                        MenuText: Text[50];
                        Selection: Option " ","Only Selected","Liquide All Credit Note";
                        LSMenu: Label '&Only selected,&All Status Credits Note';
                        lText001: Label 'All Credits Note was liquidated';
                        lText002: Label 'Credit Note No. %1 applied to product %2 en tienda %3';
                        POSExchangeTrans_l: Record "FSN POS Exchange Transaction";
                        lText003: Label 'Credit Note Cant be liquidate in status %1';
                        QryExchangeRequestLiq: Query "FSN Exchange Request Liquidate";
                        pNext: Boolean;
                        PageLiquidate: Page "FSN Liquidate Exch. Document";
                        lText004: Label 'Check Credit Note %1 ?';
                    begin


                        pNext := TRUE;
                        CLEAR(QryExchangeRequestLiq);
                        QryExchangeRequestLiq.OPEN;
                        WHILE QryExchangeRequestLiq.READ() AND pNext DO BEGIN
                            COMMIT;
                            IF CONFIRM(STRSUBSTNO(lText004, QryExchangeRequestLiq.External_Document_No)) THEN BEGIN
                                pNext := FALSE;
                                PageLiquidate.SetTemporaryCreditNote(QryExchangeRequestLiq.Status,
                                  QryExchangeRequestLiq.External_Document_No,
                                  QryExchangeRequestLiq.Max_Amount_Doc_Inc_VAT, FALSE,
                                  QryExchangeRequestLiq.Count_);
                                PageLiquidate.RUN;
                            END;
                        END;
                        QryExchangeRequestLiq.CLOSE;

                    end;
                }
                action("Try Exit Apply")
                {
                    Caption = 'Try Exit Apply';
                    Ellipsis = true;
                    Image = Apply;
                    Promoted = false;
                    Visible = OptionLiquidateVisible;

                    trigger OnAction()
                    var
                        lText001: Label 'Status must be Released. Actual Status %1';
                        ExchangeLine_l: Record "FSN POS Exchange Transaction";
                        lText002: Label 'Exit Applied succesfull. Product %1 Location %2';
                        PostedExchangeLine_l: Record "POS Posted Exchange Trans.";
                        lText003: Label 'Transaction references is Void. Exchange was void in the history';
                        lText004: Label 'Exchange is not require use inventory. Was register in history';
                    begin
                        IF NOT (Status = Status::Released) THEN
                            ERROR(STRSUBSTNO(lText001, FORMAT(Status)));

                        TransferInternalMgt.InicializeFields(Rec, "Transfer-to Code");
                        ExchangeLine_l.GET("Receipt No.", "Transaction No.", "Line No.", "Store No.", "POS Terminal No.");
                        Rec := ExchangeLine_l;

                        IF NOT (Status = Status::"Exit Applied") THEN
                            IF NOT TransferInternalMgt.TryPostExchange(Rec) THEN BEGIN
                                ExchangeLine_l.GET("Receipt No.", "Transaction No.", "Line No.", "Store No.", "POS Terminal No.");
                                MESSAGE(STRSUBSTNO(gText003, ExchangeLine_l."Process Message"));
                                EXIT;
                            END;

                        IF PostedExchangeLine_l.GET("Receipt No.", "Transaction No.", "Line No.", "Store No.", "POS Terminal No.") THEN BEGIN
                            IF PostedExchangeLine_l.Status = PostedExchangeLine_l.Status::Void THEN
                                MESSAGE(lText003)
                            ELSE
                                IF NOT PostedExchangeLine_l."Use Inventory" THEN
                                    MESSAGE(lText004);
                            EXIT;
                        END;
                        MESSAGE(STRSUBSTNO(lText002, ExchangeLine_l.GetItemDescription("Item No."), "Store No."));
                    end;
                }
                action("Analisys Track Liquidate")
                {
                    Image = AddWatch;
                    RunObject = Page "FSN POS Exch. Analisis Track";
                }
                action("Delivery Vendor")
                {
                    Caption = 'Delivery to Vendor';
                    Image = BusinessRelation;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    RunObject = Page "FSN POS Exch. Delivery Vendor";
                }
                action(SetAuthorization)
                {
                    Caption = 'Set Authorization Web';
                    Image = ApplyTemplate;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    Visible = true;

                    trigger OnAction()
                    var
                        SetTexts: array[10, 2] of Text[250];
                        SetButtonTexts: array[3, 2] of Text[250];
                        NameForm: Text[50];
                        Result: array[10] of Text[250];
                        RecordSet: array[10, 2] of Text[250];
                        lText000: Label 'Credit Note: ';
                        lText001: Label 'Amount Inc. VAT:';
                        lText002: Label 'Apply';
                        lText003: Label 'Cancel';
                        lText004: Label 'Assignement Credit Note';
                        lText005: Label 'Description';
                        ResultType: Integer;
                        DecimalConvert: Decimal;
                        lText006: Label '%1 Cant be empty';
                        lText007: Label 'Do you want apply credit note?\Store %5\No. %1\Amount $%2\Item %3\Qty. %4';
                        lText008: Label 'Record already document assigned No. %1 $%2';
                        lText009: Label 'Value cant by less than or equal Zero';
                        lText010: Label 'Authorization Web:';
                        lText011: Label 'Done!';
                        lText012: Label 'Athorization Web Register';
                        lText013: Label 'Do you want apply Athorization No. %1 ?';
                        lText014: Label 'No require authorization No.';
                    begin
                        WindowsFormNet.Testing();
                        IF NOT ("Autorization Type" = "Autorization Type"::WebPage) THEN BEGIN
                            MESSAGE(lText014);
                            EXIT;
                        END;
                        IF LSUserStore <> "Store No." THEN
                            ERROR(STRSUBSTNO(gText005, "Store No."));
                        SetTexts[1] [1] := "Web Authorization No.";
                        SetTexts[1] [2] := lText010;
                        SetButtonTexts[1] [1] := lText002;
                        SetButtonTexts[2] [1] := lText003;
                        SetButtonTexts[1] [2] := '6'; //Yes
                        SetButtonTexts[2] [2] := '2'; //Cancel

                        RecordSet[1] [1] := FIELDCAPTION("Receipt No.");
                        RecordSet[2] [1] := FIELDCAPTION("Item No.");
                        RecordSet[3] [1] := FIELDCAPTION("Unit of Measure");
                        RecordSet[4] [1] := lText005;
                        RecordSet[5] [1] := FIELDCAPTION(Quantity);
                        RecordSet[6] [1] := FIELDCAPTION("Attrib 1 Code");
                        RecordSet[1] [2] := "Receipt No.";
                        RecordSet[2] [2] := "Item No.";
                        RecordSet[3] [2] := "Unit of Measure";
                        RecordSet[4] [2] := GetItemDescription("Item No.");
                        RecordSet[5] [2] := FORMAT(Quantity);
                        RecordSet[6] [2] := "Attrib 1 Code";

                        WindowsFormNet.ShowStandarDialog(1, SetTexts, 2, SetButtonTexts, lText012, Rec.TABLECAPTION, 6, RecordSet, Result, ResultType);
                        IF ResultType <> 6 THEN
                            EXIT;

                        IF Result[1] = '' THEN
                            ERROR(STRSUBSTNO(lText006, lText000));

                        IF NOT CONFIRM(STRSUBSTNO(lText013, Result[1])) THEN
                            EXIT;

                        Rec.GET("Receipt No.", "Transaction No.", "Line No.", "Store No.", "POS Terminal No.");
                        "Web Authorization No." := UPPERCASE(Result[1]);
                        MODIFY;
                        MESSAGE(lText011);
                    end;
                }
                action(NullChange)
                {
                    Caption = 'Anular Canje';
                    Image = ApplyTemplate;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    Visible = true;

                    trigger OnAction()
                    var
                    begin
                        Rec.Status := Rec.Status::Void;
                        Rec.MODIFY;
                        CurrPage.Update();
                    end;
                }
            }
        }
        area(navigation)
        {
            action(DeliveryVendorRegister)
            {
                Caption = 'Delivery Vendor Register';
                Image = PutAwayWorksheet;

                trigger OnAction()
                begin
                    DocumentRegisterPage.SetFilterSessionStoreExchange;
                    DocumentRegisterPage.RUN;
                end;
            }
            action(ReceiptFromVendorRegister)
            {
                Caption = 'Receipt From Vendor Register';
                Image = JobRegisters;

                trigger OnAction()
                begin
                    DocumentRegisterPage.SetFilterSessionRcptExhange();
                    DocumentRegisterPage.RUN;
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        Item_l: Record "Item";
        Vendor_l: Record "Vendor";
    begin
        IF "Item No." <> '' THEN BEGIN
            IF Item_l.GET("Item No.") THEN BEGIN
                //ItemAttrib1Code := Item_l."Attrib 1 Code";
                IF Item_l."Vendor No." <> '' THEN
                    IF Vendor_l.GET(Item_l."Vendor No.") THEN
                        ItemPrimaryVendor := Vendor_l.Name;
            END;
        END;
        CostAmount := "Unit Cost" * Quantity;

        SetStyleText := 'None';
        SetStyleTextRequire := 'None';
        CASE Status OF
            Status::Released:
                SetStyleText := 'Unfavorable';
            Status::"Exit Applied":
                SetStyleText := 'Favorable';
            Status::"Liquidate Product", Status::"Liquidate CreditNote", Status::"Request Liquidate CN":
                SetStyleText := 'StrongAccent';
        END;
        CASE Request OF
            Request::DeliveryToVendor:
                SetStyleTextRequire := 'Unfavorable';
            Request::Delivered:
                SetStyleTextRequire := 'Favorable';
            Request::ReceivedByVendor:
                SetStyleTextRequire := 'Strong';
        END;
    end;

    trigger OnOpenPage()
    var
        UserRetail: Record "LSC Retail User";
    begin
        LSUserStore := '';
        IF UserRetail.GET(USERID) THEN
            IF UserRetail."Store No." <> '' THEN BEGIN
                FILTERGROUP(2);
                SETRANGE("Store No.", UserRetail."Store No.");
                FILTERGROUP(0);
                LSUserStore := UserRetail."Store No.";
            END;
    end;

    var
        TransferInternalMgt: Codeunit "FSN Internal Transfer Manager";
        gText003: Label 'Error %1';
        gText001: Label 'Sure to liquidate product %1 ?. It will be charged to your inventory';
        ItemAttrib1Code: Text[50];
        ItemPrimaryVendor: Text[50];
        SetStyleText: Text[50];
        CostAmount: Decimal;
        gText004: Label 'Request must be Delivery To Vendor. Require actual: %1';
        LSUserStore: Code[10];
        gText005: Label 'User must be assigned to Store %1';
        SetStyleTextRequire: Text[50];
        DocumentRegisterPage: Page "FSN Documents Rcvd. Posted";
        WindowsFormNet: Codeunit "FSN Windows Forms NET";
        gText006: Label 'Action is not possible, request actual: %1';
        OptionLiquidateVisible: Boolean;

    procedure SetOptionLiquidateVisible(pVisible: Boolean)
    begin
        OptionLiquidateVisible := pVisible
    end;
}

