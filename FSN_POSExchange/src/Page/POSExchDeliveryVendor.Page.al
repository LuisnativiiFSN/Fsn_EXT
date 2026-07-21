page 50032 "FSN POS Exch. Delivery Vendor"
{

    Caption = 'POS Exch. Delivery Vendor';
    DelayedInsert = false;
    DeleteAllowed = false;
    InsertAllowed = false;
    PageType = List;
    SourceTable = "FSN POS Exchange Transaction";
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTableView = SORTING(Request, "Document Return Key 1", "Document Return Key 2")
                      ORDER(Descending);

    layout
    {
        area(content)
        {
            group(General)
            {
                field(DocumentVendor; DocumentVendor)
                {
                    Caption = 'Document Delivery Vendor';
                }
                field(VendorCode; VendorCode)
                {
                    Caption = 'VendorCode';
                    DrillDown = true;
                    LookupPageID = "LSC Store Vendor List";
                    QuickEntry = false;
                    TableRelation = Vendor;
                }
                field(DocumentDate; DocumentDate)
                {
                    Caption = 'Document Date';

                    trigger OnValidate()
                    begin
                        IF DocumentDate = 0D THEN
                            DocumentDate := TODAY;
                    end;
                }
            }
            repeater(Group)
            {
                field("Receipt No."; "Receipt No.")
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
                    Enabled = false;
                }
                field(Quantity; Quantity)
                {
                    Editable = false;
                }
                field(GetItemDescription; GetItemDescription("Item No."))
                {
                    Editable = false;
                }
                field(Select; Select)
                {

                    trigger OnValidate()
                    begin
                        IF UserLS."Store No." <> "Store No." THEN
                            ERROR(STRSUBSTNO(Text013, "Store No."));
                        MODIFY;
                        CurrPage.UPDATE(FALSE);
                    end;
                }
                field(Request; Request)
                {
                    Editable = false;
                    Style = Unfavorable;
                    StyleExpr = TRUE;
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
                field("Sales Staff"; "Sales Staff")
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
                field("Unit Cost"; "Unit Cost")
                {
                    Editable = false;
                }
                field("Attrib 1 Code"; "Attrib 1 Code")
                {
                    Enabled = false;
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
                action("Process Delivery")
                {
                    Caption = 'Process Delivery';
                    Image = Confirm;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;

                    trigger OnAction()
                    var
                        Vendo_l: Record "vendor";
                        VendorTmp: Record "vendor" temporary;
                        SkypVal: Boolean;
                    begin
                        FasaniServerUtil.GET(UserLS."Store No.");
                        IF VendorCode = '' THEN
                            ERROR(Text007);
                        Vendor.GET(VendorCode);

                        //WVILLALTA10ENE2020-
                        IF DocumentVendor = '' THEN BEGIN
                            VendorTmp.RESET;
                            VendorTmp.DELETEALL;
                            Vendo_l.RESET;
                            Vendo_l.SETFILTER(Vendo_l."No.", FasaniServerUtil."Exch. Internal Vendor Filter");
                            IF Vendo_l.FINDSET THEN
                                REPEAT
                                    VendorTmp.INIT();
                                    VendorTmp := Vendo_l;
                                    VendorTmp.INSERT;
                                UNTIL Vendo_l.NEXT = 0;

                            SkypVal := VendorTmp.GET(VendorCode);
                            IF SkypVal THEN BEGIN
                                DocumentVendor := NoSeriesMgt.GetNextNo(FasaniServerUtil."No. Serie Exch.Inter.Vendor", TODAY, TRUE);//WVILLALTA10ENE2020-;
                                COMMIT;//WVILLALTA 8.20
                            END;
                        END;

                        IF DocumentVendor = '' THEN
                            ERROR(Text001);

                        ExternalDocuments2.RESET;
                        ExternalDocuments2.SETCURRENTKEY("External Document No.", "Customer No. Related", "Vendor No.", Status);
                        ExternalDocuments2.SETRANGE(ExternalDocuments2."External Document No.", DocumentVendor);
                        ExternalDocuments2.SETRANGE(ExternalDocuments2."Vendor No.", VendorCode);
                        ExternalDocuments2.SETRANGE(ExternalDocuments2.Status, ExternalDocuments2.Status::Posted);
                        IF ExternalDocuments2.FINDFIRST THEN
                            ERROR(STRSUBSTNO(Text008, ExternalDocuments2."External Document No.", Vendor.Name));

                        IF NOT CONFIRM(STRSUBSTNO(Text000, DocumentVendor)) THEN
                            EXIT;

                        Counter := 0;
                        CostAmount := 0;
                        EntryNext := 0;
                        GlobalTemporary.RESET;
                        GlobalTemporary.DELETEALL;
                        CLEAR(GlobalTemporary);
                        ExternalDocumentDiscLoc.RESET;
                        CLEAR(ExternalDocumentDiscLoc);
                        ExternalDocuments.RESET;
                        CLEAR(ExternalDocuments);
                        ExternalDocuments.INIT();
                        ExternalDocuments."User ID" := USERID;

                        ExternalDocuments2.RESET;
                        ExternalDocuments2.SETCURRENTKEY("Entry Posted No.");
                        IF ExternalDocuments2.FINDLAST THEN
                            EntryNext := ExternalDocuments2."Entry Posted No." + 1
                        ELSE
                            EntryNext := 1;

                        POSExchangeTransaction.RESET;
                        POSExchangeTransaction.COPYFILTERS(Rec);
                        POSExchangeTransaction.SETRANGE(POSExchangeTransaction.Select, TRUE);
                        IF POSExchangeTransaction.FIND('-') THEN
                            REPEAT
                                IF POSExchangeTransaction."Store No." <> UserLS."Store No." THEN
                                    ERROR(STRSUBSTNO(Text013, POSExchangeTransaction."Store No."));

                                IF NOT ItemVendor.GET(VendorCode, POSExchangeTransaction."Item No.", '') THEN
                                    ERROR(STRSUBSTNO(Text012, POSExchangeTransaction.GetItemDescription(POSExchangeTransaction."Item No."), Vendor.Name));

                                CodeTransfer := '';
                                IF POSExchangeTransaction.Status = POSExchangeTransaction.Status::Released THEN
                                    TransferInternalMgt.InicializeFields(POSExchangeTransaction, CodeTransfer);

                                POSExchangeTransaction2.GET(POSExchangeTransaction."Receipt No.", POSExchangeTransaction."Transaction No.", POSExchangeTransaction."Line No.",
                                  POSExchangeTransaction."Store No.", POSExchangeTransaction."POS Terminal No.");

                                IF POSExchangeTransaction2."Unit Cost" = 0 THEN
                                    ERROR(STRSUBSTNO(Text009, POSExchangeTransaction2.GetItemDescription(POSExchangeTransaction2."Item No.")));
                                POSExchangeTransaction2.Request := POSExchangeTransaction2.Request::Delivered;
                                POSExchangeTransaction2.Select := FALSE;
                                POSExchangeTransaction2."Vendor Document No." := DocumentVendor;
                                POSExchangeTransaction2."Document Return Key 1" := ExternalDocuments."User ID";
                                POSExchangeTransaction2."Document Return Key 2" := EntryNext;
                                POSExchangeTransaction2.MODIFY;
                                Counter += 1;
                                CostAmount += ROUND(POSExchangeTransaction2."Unit Cost" * POSExchangeTransaction2.Quantity, 0.01, '=');
                                Store.GET(POSExchangeTransaction2."Store No.");
                                Store.TESTFIELD("Location Code");
                                Item.GET(POSExchangeTransaction."Item No.");
                                IF NOT GlobalTemporary.GET(Store."Location Code", Store."Location Code", Store."Location Code", Store."Location Code", 0, 0) THEN BEGIN
                                    GlobalTemporary.INIT();
                                    GlobalTemporary.Code10_1 := Store."Location Code";
                                    GlobalTemporary.Code10_2 := Store."Location Code";
                                    GlobalTemporary.Code20_1 := Store."Location Code";
                                    GlobalTemporary.Code20_2 := Store."Location Code";
                                    GlobalTemporary.Int_1 := 0;
                                    GlobalTemporary.Counter1 := 0;
                                    GlobalTemporary.Decimal_1 := 0;
                                    GlobalTemporary.Decimal_2 := 0;
                                    GlobalTemporary.INSERT();
                                END;
                                GlobalTemporary.Decimal_1 += ROUND(POSExchangeTransaction2."Unit Cost" * POSExchangeTransaction2.Quantity, 0.01, '=');
                                VATPostingSetup.RESET;
                                CLEAR(VATPostingSetup);
                                IF Vendor."VAT Bus. Posting Group" <> '' THEN
                                    VATPostingSetup.GET(Vendor."VAT Bus. Posting Group", Item."VAT Prod. Posting Group")
                                ELSE
                                    VATPostingSetup.GET(Item."VAT Bus. Posting Gr. (Price)", Item."VAT Prod. Posting Group");

                                IF VATPostingSetup."VAT Prod. Posting Group" <> '' THEN
                                    GlobalTemporary.Decimal_2 += (ROUND(POSExchangeTransaction2."Unit Cost" * POSExchangeTransaction2.Quantity, 0.01, '=') *
                                        (VATPostingSetup."VAT %" / 100))
                                ELSE
                                    GlobalTemporary.Decimal_2 += 0;

                                GlobalTemporary.MODIFY();

                            UNTIL POSExchangeTransaction.NEXT = 0;
                        IF Counter = 0 THEN
                            ERROR(Text011);

                        FasaniServerUtil.GET(UserLS."Store No.");
                        SerieSelect := NoSeriesMgt.GetNextNo(FasaniServerUtil."No. Serie Return Exchange", TODAY, TRUE);

                        ExternalDocuments."Entry Posted No." := EntryNext;
                        ExternalDocuments."Entry Type" := ExternalDocuments."Entry Type"::Purchase;
                        ExternalDocuments."Document Type" := ExternalDocuments."Document Type"::"Delivery To Vendor";
                        ExternalDocuments."Group Type" := ExternalDocuments."Group Type"::Exchange;
                        ExternalDocuments."External Document No." := DocumentVendor;
                        ExternalDocuments."Date Document" := DocumentDate;
                        ExternalDocuments.Comment := Text002;
                        ExternalDocuments."Vendor No." := VendorCode;
                        ExternalDocuments."Posting Date" := TODAY;
                        ExternalDocuments.Status := ExternalDocuments.Status::Posted;
                        ExternalDocuments."Order No. Related" := '';
                        ExternalDocuments."Customer No. Related" := '';
                        ExternalDocuments."(Order) Invoice No." := '';
                        ExternalDocuments."Document Type Text" := FORMAT(ExternalDocuments."Document Type"::"Delivery To Vendor");
                        ExternalDocuments.Description := STRSUBSTNO(Text006, Vendor.Name);
                        ExternalDocuments."VAT Prod. Posting Group" := '';
                        ExternalDocuments."Store LS Retail" := UserLS."Store No.";
                        ExternalDocuments."Reference Key" := SerieSelect;
                        ExternalDocuments.INSERT(TRUE);

                        IF GlobalTemporary.FIND('-') THEN
                            REPEAT
                                ExternalDocumentDiscLoc."Document Entry No." := EntryNext;
                                ExternalDocumentDiscLoc."Location Code" := GlobalTemporary.Code10_1;
                                ExternalDocumentDiscLoc."Net Amount" := -GlobalTemporary.Decimal_1;
                                ExternalDocumentDiscLoc."VAT Amount" := -ROUND(GlobalTemporary.Decimal_2, 0.01, '=');
                                ExternalDocumentDiscLoc."Total Amount" := -GlobalTemporary.Decimal_1 + ROUND(-GlobalTemporary.Decimal_2, 0.01, '=');
                                ExternalDocumentDiscLoc."% Distribution" := ROUND(ExternalDocumentDiscLoc."Net Amount" / CostAmount, 0.001, '=') * 100;
                                ExternalDocumentDiscLoc."Type Distribution" := ExternalDocumentDiscLoc."Type Distribution"::"Suggest by System";
                                ExternalDocumentDiscLoc."Posting Date" := TODAY;
                                ExternalDocumentDiscLoc."Document Date" := DocumentDate;
                                ExternalDocumentDiscLoc.INSERT(TRUE);
                            UNTIL GlobalTemporary.NEXT = 0;
                        COMMIT;
                        DocumentVendor := '';
                        PagePrintDocument.PrintDocument(ExternalDocuments);

                        //COMMIT;
                        //MESSAGE(STRSUBSTNO(Text010,DocumentVendor));
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
                //The property 'PromotedIsBig' can only be set if the property 'Promoted' is set to 'true'
                //PromotedIsBig = true;

                trigger OnAction()
                begin
                    DocumentRegisterPage.SetFilterSessionStoreExchange;
                    DocumentRegisterPage.RUN;
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        DocumentDate := TODAY;
        CLEAR(UserLS);
        IF UserLS.GET(USERID) THEN;

        FILTERGROUP(2);
        SETCURRENTKEY(Request, "Document Return Key 1", "Document Return Key 2");
        //SETRANGE(Request, Request::DeliveryToVendor);
        SETRANGE(Request, Request::None, Request::DeliveryToVendor);
        IF UserLS."Store No." <> '' THEN
            SETRANGE("Store No.", UserLS."Store No.");

        FILTERGROUP(0);
    end;

    var
        DocumentVendor: Code[20];
        Text000: Label 'Appy document %1 to all selected?';
        VendorCode: Code[20];
        DocumentDate: Date;
        POSExchangeTransaction: Record "FSN POS Exchange Transaction";
        Text001: Label 'Document No. cant be empty';
        POSExchangeTransaction2: Record "FSN POS Exchange Transaction";
        ExternalDocuments: Record "FSN Document Received Entry";
        ExternalDocuments2: Record "FSN Document Received Entry";
        ExternalDocumentDiscLoc: Record "FSN Document Rcvd. Location";
        Vendor: Record "vendor";
        Store: Record "LSC Store";
        UserLS: Record "LSC Retail User";
        ItemVendor: Record "Item Vendor";
        Counter: Integer;
        CostAmount: Decimal;
        EntryNext: Integer;
        Text002: Label 'Delivery to Vendor. Exchanges';
        Text006: Label 'Vendor %1';
        Text007: Label 'Vendor No. cant be empty';
        Text008: Label 'Document %1 alredy exists for vendor %2';
        TransferInternalMgt: Codeunit "FSN Internal Transfer Manager";
        CodeTransfer: Code[10];
        Text009: Label 'Error Item setup %1, Unit Cost cant be zero.';
        Text010: Label 'Done!.Return To Vendor %1 registered.';
        Text011: Label 'There must be at least one record selected';
        Text012: Label 'Item %1 is no associate to vendor %2';
        DocumentRegisterPage: Page "FSN Documents Rcvd. Posted";
        Text013: Label 'User must be assignment to store %1';
        VATPostingSetup: Record "VAT Posting Setup";
        VATPostingSetupItem: Record "VAT Posting Setup";
        GlobalTemporary: Record "FSN Global Table Temporary" temporary;
        Item: Record "Item";
        SerieSelect: Code[20];
        NoSeriesMgt: Codeunit "NoSeriesManagement";
        FasaniServerUtil: Record "FSN Fasani Setup";
        PagePrintDocument: Page "FSN Documents Rcvd. Posted";
}

