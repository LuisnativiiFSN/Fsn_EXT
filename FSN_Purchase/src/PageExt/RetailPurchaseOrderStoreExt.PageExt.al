pageextension 50061 "FSN RetailPurchOrderStoreExt" extends "LSC Retail Purch. Order Store" //"LSC Retail Purchase Order Store"
{
    layout
    {
        addafter("Location Code")
        {
            field("FSN Alternative Order"; Rec."FSN Alternative Order")
            {
                ApplicationArea = All;
                DrillDown = true;
                trigger OnDrillDown()
                var
                    PurchaseHeader: Record "Purchase Header";
                begin
                    PurchaseHeader.Reset();
                    PurchaseHeader.SetRange("Your Reference", Rec."No.");
                    if PurchaseHeader.FindFirst() then begin
                        Page.Run(Page::"LSC Retail Purch. Order Store", PurchaseHeader);
                    end;
                end;
            }
            field("FSN Shared with EBS"; Rec."FSN Shared with EBS")
            {
                ApplicationArea = All;
            }
            field("FSN Outstanding Lines"; Rec."FSN Outstanding Lines")
            {
                ApplicationArea = All;
            }
        }
    }

    actions
    {
        addafter(Release)
        {
            action(SendExternalLines)
            {
                Caption = 'Send External Lines';
                Image = CopyFromChartOfAccounts;
                Promoted = true;
                PromotedCategory = Process;
                trigger OnAction()
                var
                    PurchExternalManager: Codeunit "FSN Batch - Send Purchase Data";
                    //Vendor_l: Record Vendor;
                    Store_l: Record "LSC Store";
                    FasaniPurchSetup_l: Record "FSN Fasani Setup";
                    ExternalLines_l: Record "FSN External Purch. Line";
                    IDSelected: Option " ","Only Selected","All Transfer";
                    Ok_: Boolean;
                    LSMenu: Text[100];
                    lText001: Label 'External Lines already exists';
                    lText002: Label 'Sincronized lines sussesfull...';
                    lText003: Label 'Vendor %1 is not allowed for purchase external lines';
                    lText004: Label 'Vendor and Status Released is required for this action';
                    lText005: Label 'Location %1 is not allowed use puchase external lines';
                    lText006: Label 'Consolidate cant be empty';
                    lTextMenu: Label '&Purchase Selected %1, &All Purchase Orders';
                    scheduler: Record "LSC Scheduler Job Header";
                begin
                    LSMenu := STRSUBSTNO(lTextMenu, "No.");
                    IDSelected := STRMENU(LSMenu, 1);

                    CASE IDSelected OF
                        0:
                            EXIT;
                        2:
                            BEGIN
                                scheduler.init();
                                PurchExternalManager.RUN(scheduler);
                                MESSAGE(lText002);
                                EXIT;
                            END;
                    END;

                    Ok_ := FALSE;
                    IF ("Buy-from Vendor No." = '') OR (Status <> Status::Released) THEN
                        ERROR(lText004);

                    IF Rec."FSN Consolidate No." = '' THEN
                        ERROR(lText006);

                    ExternalLines_l.RESET;
                    ExternalLines_l.SETCURRENTKEY("No.", "Line No.");
                    ExternalLines_l.SETRANGE(ExternalLines_l."No.", "No.");
                    IF ExternalLines_l.FINDFIRST THEN BEGIN
                        MESSAGE(lText001);
                        EXIT;
                    END;

                    IF "LSC Store No." <> '' THEN
                        Ok_ := FasaniPurchSetup_l.GET("LSC Store No.")
                    ELSE BEGIN
                        Store_l.RESET;
                        Store_l.SETCURRENTKEY("Location Code");
                        IF Store_l.FINDFIRST THEN
                            Ok_ := FasaniPurchSetup_l.GET(Store_l."No.");
                    END;
                    IF Ok_ THEN BEGIN
                        IF FasaniPurchSetup_l."Use External Purch. Line" THEN BEGIN
                            PurchExternalManager.SendCreateExternalLines(Rec);
                            MESSAGE(lText002);
                            EXIT;
                        END ELSE
                            Ok_ := FALSE;
                    END;
                    IF NOT Ok_ THEN
                        MESSAGE(STRSUBSTNO(lText005, "Ship-to Name"));
                end;
            }
            action(CreatePurchaseOrderAlternative)
            {
                ApplicationArea = all;
                Caption = 'Crear Pedido Alternativo';
                Image = NewPurchaseInvoice;
                Promoted = true;
                PromotedCategory = Process;
                ShortCutKey = 'Shift+F8';
                PromotedIsBig = true;
                ToolTip = 'Crear un pedido alternativo de las lineas no recepcionadas';
                trigger OnAction()
                var
                    Vend: Record Vendor;
                    FSNExternalPurchMgr: Codeunit "FSN External Purch. Manager";
                begin
                    if Rec."FSN Shared with EBS" then begin
                        if PAGE.RunModal(PAGE::"Vendor List", Vend) = ACTION::LookupOK then begin
                            FSNExternalPurchMgr.CreatePurchaseOrderAlternative(Vend, Rec);
                        end;
                    end else
                        Error('Si el pedido %1 no ha sido autorizada y compartida con EBS, no se puede crear un pedido alternativo.', Rec."No.");
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
                    recReport.SetFilter("No.", '%1', Rec."No.");
                    if recReport.FindFirst() then
                        Report.Run(50081, true, false, recReport);
                end;
            }

        }
        addafter(PostedPurchaseInvoices)
        {
            action("External Lines")
            {
                PromotedCategory = Category9;
                Promoted = true;
                Image = SuggestElectronicDocument;
                trigger OnAction()
                var
                    ExternalLinepage: Page "FSN External Purch. Line";
                begin
                    ExternalLinepage.SETFILTERNO(Rec."No.");
                    ExternalLinepage.Run();
                end;
            }
        }

        addafter(Receipts)
        {
            action(Recerva)
            {
                Caption = 'FSN Recervacion';
                Image = CopyFromChartOfAccounts;
                ApplicationArea = all;
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Category9;
                trigger OnAction()
                var
                    FsnRecerva: Page "FSN Reservado";
                begin
                    FsnRecerva.Run();
                end;
            }
        }


    }

}

