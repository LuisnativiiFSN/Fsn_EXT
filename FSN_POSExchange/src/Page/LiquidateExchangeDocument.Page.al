page 50038 "FSN Liquidate Exch. Document"
{

    Caption = 'FSN Liquidate Exchange Document';
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    PageType = ListPlus;
    ShowFilter = true;
    SourceTable = "FSN POS Exchange Transaction";
    SourceTableTemporary = true;
    ApplicationArea = All;
    UsageCategory = Administration;


    layout
    {
        area(content)
        {
            group(DocumentData)
            {
                Caption = 'Document Data';
                field(DocumentType; DocumentoType_)
                {
                    Caption = 'Entry Type';
                    Editable = UnblockDocumentType;
                    OptionCaption = 'Item By Item,Credit Note,Purch Receipt,Other';

                    trigger OnValidate()
                    begin
                        DocumentTypeOnValidate;
                    end;
                }
                field(ExternalDoc_; ExternalDoc_)
                {
                    Caption = 'Credit Note / External Document';
                    Enabled = ExtDocAndAmtVisible;
                }
                field(AmtExternalDoc_; AmtExternalDoc_)
                {
                    Caption = 'Amount External Doc. Inc.VAT';
                    DecimalPlaces = 2 : 2;
                    Enabled = ExtDocAndAmtVisible;
                }
                field(OtherDescrDocType; OtherDescriptionTypeDoc)
                {
                    Caption = 'Other Description Doc. Type';
                    Enabled = OtherDescrptionVisible;
                    Visible = true;
                }
                field(SearchPurchReceipt; SearchPurchReceipt)
                {
                    Caption = 'Search Purch Receipt';
                    Enabled = SearchPurchReceiptVisible;

                    trigger OnDrillDown()
                    var
                        PurchReceiptHeader: Page "Posted Purchase Invoices";
                        PurchReceipHeader_l: Record "Purch. Rcpt. Header";
                        Store_l: Record "LSC Store";
                        lText001: Label 'Store %1 or Location not exists';
                    begin
                    end;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        PurchInvHeader_l: Record "Purch. Inv. Header";
                        PagePurchHeader: Page "Posted Purchase Invoices";
                        Text_: Text;
                    begin
                        PurchInvHeader_l.RESET;
                        PurchInvHeader_l.SETCURRENTKEY("Vendor Invoice No.", "Posting Date");
                        PurchInvHeader_l.SETRANGE(PurchInvHeader_l."LSC Store No.", "Store No.");
                        PurchInvHeader_l.SETRANGE(PurchInvHeader_l."Posting Date", CALCDATE('<-7D>', TODAY), TODAY);
                        PagePurchHeader.LOOKUPMODE := TRUE;
                        PagePurchHeader.SETTABLEVIEW(PurchInvHeader_l);
                        IF PagePurchHeader.RUNMODAL = ACTION::LookupOK THEN BEGIN
                            //Text_ := PagePurchHeader.GetSelectionRecord;
                            Text_ := PurchInvHeader_l."No.";
                            IF STRPOS(Text_, '|') > 0 THEN
                                Text_ := COPYSTR(Text_, 1, STRPOS(Text_, '|') - 1);
                            Text_ := DELCHR(Text_, '=', '''');
                            ValidatePurchaseInvoice(Text_);
                            SearchPurchReceipt := Text_;
                        END ELSE
                            EXIT(FALSE);
                    end;

                    trigger OnValidate()
                    begin
                        IF SearchPurchReceipt <> '' THEN BEGIN
                            ValidatePurchaseInvoice(SearchPurchReceipt);
                        END;
                    end;
                }
                field(VendorSelect; VendorSelect)
                {
                    Caption = 'VendorSelect';
                    LookupPageID = "LSC Store Vendor List";
                    TableRelation = Vendor;
                }
            }
            group(General)
            {
                field(Barcode; Barcode)
                {
                    Caption = 'Barcode Scan';

                    trigger OnValidate()
                    var
                        Exchange_l: Record "FSN POS Exchange Transaction";
                        Barcode_l: Record "LSC Barcodes";
                        ItemCode: Code[20];
                        Item_l: Record "Item";
                        ItemDescription: Text[50];
                        ExchangeSelect_l: Record "FSN POS Exchange Transaction";
                        ExchangesPage: Page "FSN POS Exchange Scann";
                        BarraCodeLocal: Code[20];
                    begin
                        //WVILLALTA04DIC19-
                        BarraCodeLocal := Barcode;
                        Barcode := '';

                        IF GlobalPermitedInsertCreditNote THEN
                            EXIT;

                        IF UserLS."Store No." = '' THEN BEGIN
                            MESSAGE(Text011);
                            EXIT;
                        END;
                        CLEAR(ItemCode);
                        IF Barcode_l.GET(BarraCodeLocal) THEN BEGIN
                            ItemCode := Barcode_l."Item No.";
                            ItemDescription := Barcode_l.Description;
                        END;
                        IF ItemCode = '' THEN BEGIN
                            IF NOT Item_l.GET(BarraCodeLocal) THEN BEGIN
                                MESSAGE(STRSUBSTNO(Text020, BarraCodeLocal));
                                EXIT;
                            END;
                            ItemCode := Item_l."No.";
                            ItemDescription := Item_l.Description;
                        END;
                        Barcode := '';
                        Exchange_l.RESET;
                        Exchange_l.SETCURRENTKEY("Item No.", "Unit of Measure", "Store No.", "Transaction Date", Quantity);
                        Exchange_l.SETRANGE(Exchange_l."Item No.", ItemCode);
                        Exchange_l.SETRANGE(Exchange_l."Store No.", UserLS."Store No.");
                        Exchange_l.SETRANGE(Exchange_l."Document Receipt Key 1", '');
                        Exchange_l.SETFILTER(Exchange_l.Status, '<>%1', Exchange_l.Status::"Request Liquidate CN");
                        CASE Exchange_l.COUNT OF
                            1:
                                BEGIN
                                    Exchange_l.FIND('-');
                                    IF Rec.GET(Exchange_l."Receipt No.", Exchange_l."Transaction No.", Exchange_l."Line No.", Exchange_l."Store No.", Exchange_l."POS Terminal No.") THEN BEGIN
                                        MESSAGE(Text012);
                                        EXIT;
                                    END;
                                    IF Exchange_l."Receipt No." = '' THEN
                                        EXIT;
                                    Rec.RESET;
                                    Rec.INIT();
                                    Rec := Exchange_l;
                                    Rec.INSERT();
                                END;
                            0:
                                BEGIN
                                    MESSAGE(Text013, ItemDescription);
                                END;
                            ELSE BEGIN
                                ExchangeSelect_l.RESET;
                                CLEAR(ExchangeSelect_l);
                                ExchangesPage.LOOKUPMODE(TRUE);
                                ExchangesPage.SETTABLEVIEW(Exchange_l);
                                IF ExchangesPage.RUNMODAL = ACTION::LookupOK THEN BEGIN
                                    ExchangesPage.GetSelection(ExchangeSelect_l);

                                    IF ExchangeSelect_l."Receipt No." = '' THEN
                                        EXIT;

                                    Rec.RESET;
                                    Rec := ExchangeSelect_l;
                                    Rec.INSERT();
                                END;
                            END;
                        END;
                        Barcode := '';
                        //WVILLALTA04DIC19+
                    end;
                }
            }
            repeater(Group)
            {
                field(Selected; Selected)
                {
                    Caption = 'Selected';

                    trigger OnValidate()
                    begin
                        //WVILLALTA04DIC19-
                        IF GlobalPermitedInsertCreditNote THEN
                            Selected := TRUE
                        ELSE BEGIN
                            Rec.DELETE;
                            CurrPage.UPDATE(FALSE);
                        END;

                        //WVILLALTA04DIC19+
                    end;
                }
                field("Receipt No."; "Receipt No.")
                {
                }
                field("Line No."; "Line No.")
                {
                }
                field("Transaction Date"; "Transaction Date")
                {
                }
                field("Store No."; "Store No.")
                {
                    Enabled = false;
                }
                field("Item No."; "Item No.")
                {
                }
                field("Unit of Measure"; "Unit of Measure")
                {
                    Enabled = false;
                }
                field(Quantity; Quantity)
                {
                }
                field(ItemDescription; GetItemDescription("Item No."))
                {
                    Caption = 'ItemDescription';
                }
                field("Vendor Document No."; "Vendor Document No.")
                {
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
            action(Liquidate)
            {
                Caption = 'Liquidate';
                Image = Process;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    ExchangeLine_l: Record "FSN POS Exchange Transaction";
                    lText001: Label 'Relation Hist. Invoice No. %1, Order No. %2, Vendor Invoice No. %3';
                    lText002: Label 'Entry item only. Without external document';
                    lText003: Label 'Entry item whit document type %1';
                    PurchInvHeader_l: Record "Purch. Inv. Header";
                    InternalTransferManager: Codeunit "FSN Internal Transfer Manager";
                    lText004: Label 'Error : %1';
                    lText005: Label 'Liquidate sussesfull...';
                    Vendor_l: Record "vendor";
                    Item_l: Record "Item";
                    lText006: Label 'Vendor %1 is deny for liquidate Credit Note for user retail';
                    lText007: Label '"Vendor Invoice No." cant equal to "Credit Note / External Document"';
                    UPDExchange_l: Record "FSN POS Exchange Transaction";
                    TextType01: Label 'Product by Product';
                    TextType02: Label 'Credit Note';
                    TextType03: Label 'Purchase Receipt';
                    TextType04: Label 'Other Type';
                begin
                    //ItemOnly,CreditNote,CreditNoteAndItem,Purch_Receipt,Other
                    CLEARLASTERROR();
                    IF (VendorSelect = '') OR NOT Vendor.GET(VendorSelect) THEN
                        ERROR(Text014);

                    CASE DocumentoType_ OF
                        DocumentoType_::CreditNote:
                            BEGIN
                                IF (ExternalDoc_ = '') OR NOT (AmtExternalDoc_ > 0) THEN
                                    ERROR(STRSUBSTNO(Text005, FORMAT(DocumentoType_)));
                            END;
                        DocumentoType_::Purch_Receipt:
                            BEGIN
                                ValidatePurchaseInvoice(SearchPurchReceipt);
                                IF (ExternalDoc_ = '') OR NOT (AmtExternalDoc_ > 0) THEN
                                    ERROR(STRSUBSTNO(Text007, FORMAT(DocumentoType_)));
                            END;
                        DocumentoType_::Other:
                            BEGIN
                                IF (OtherDescriptionTypeDoc = '') OR (ExternalDoc_ = '') THEN
                                    ERROR(STRSUBSTNO(Text006, FORMAT(DocumentoType_)));
                            END;
                    END;

                    //WVILLALTA04DIC19-
                    //InternalTransferManager.SetModifyMessageProcess(TRUE);

                    //ItemOnly = 0,CreditNote = 1,Purch_Receipt = 2,Other = 3
                    MessageSet := '';
                    CASE DocumentoType_ OF
                        DocumentoType_::Purch_Receipt:
                            BEGIN
                                PurchInvHeader_l.GET(SearchPurchReceipt);
                                IF PurchInvHeader_l."Vendor Invoice No." = ExternalDoc_ THEN
                                    ERROR(lText007);
                                IF NOT CONFIRM(STRSUBSTNO(Text010, TextType03, PurchInvHeader_l."No.", "Store No.")) THEN
                                    EXIT;

                                MessageSet := STRSUBSTNO(_Text001, PurchInvHeader_l."No.", PurchInvHeader_l."Order No.", PurchInvHeader_l."Vendor Invoice No.");
                                CreateDocumentEntryLink(FALSE, DocumentoType_);
                            END;
                        DocumentoType_::ItemOnly, DocumentoType_::Other:
                            BEGIN
                                IF DocumentoType_ = DocumentoType_::ItemOnly THEN
                                    IF NOT CONFIRM(STRSUBSTNO(Text008, TextType01, "Store No.")) THEN
                                        EXIT;
                                IF DocumentoType_ = DocumentoType_::Other THEN
                                    IF NOT CONFIRM(STRSUBSTNO(Text008, TextType04, "Store No.")) THEN
                                        EXIT;
                                CreateDocumentEntryLink(TRUE, DocumentoType_);
                            END;
                        DocumentoType_::CreditNote:
                            BEGIN
                                IF NOT CONFIRM(STRSUBSTNO(Text009, TextType02)) THEN
                                    EXIT;
                                CreateDocumentEntryLink(FALSE, DocumentoType_);
                            END;
                    END; //WVILLALTA04DIC19+
                    ExternalDoc_ := '';
                    AmtExternalDoc_ := 0;
                    VendorSelect := '';
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        Selected := ("Receipt No." <> '');
    end;

    trigger OnDeleteRecord(): Boolean
    begin
        Rec.DELETE;
        CurrPage.UPDATE(FALSE);
    end;

    trigger OnOpenPage()
    begin
        UserLS.RESET;
        CLEAR(UserLS);
        IF UserLS.GET(USERID) THEN;
    end;

    var
        DocumentoType_: Option ItemOnly,CreditNote,Purch_Receipt,Other;
        ExternalDoc_: Code[20];
        AmtExternalDoc_: Decimal;
        ExtDocAndAmtVisible: Boolean;
        OtherDescriptionTypeDoc: Text[20];
        OtherDescrptionVisible: Boolean;
        SearchPurchReceiptVisible: Boolean;
        SearchPurchReceipt: Code[20];
        Text001: Label 'Item Only. Apply transfer internal to store %1 upload inventory';
        Text_: Text[35];
        AssistText: Text;
        Text002: Label 'Purch. Invoice selected not contain Item %1';
        Text003: Label 'Is not possible apply in status %1, Receipt %2';
        Text004: Label 'Number Purchase Invoice cant be empty';
        Text005: Label 'Credit Note / External Document o Amount cant be empty in Entry type %1';
        Text006: Label '"Credit Note/External Document" or "description the other type document" cant be emtpy in Entry type %1';
        Text007: Label 'Credit Note/External Document and Amount is require for liquidate Purchase Receipt selected';
        Text008: Label 'Entry Type %1 \ -> All items in this document \ -> Inventory will be loaded in Store %2 \ Continue? ';
        Text009: Label 'Entry Type %1 \ -> All items in this document \ -> In this Type Inventory not adjusted \ Continue?';
        Text010: Label 'Entry Type %1 \ -> All items in this document \ -> In this Type Inventory not adjusted \ -> Inventory was afected in Puchase Inv. Header %2 \Continue?';
        Barcode: Code[20];
        VendorSelect: Code[20];
        UserLS: Record "LSC Retail User";
        Text011: Label 'Must be assignt to one Store';
        Text012: Label 'Record already add.';
        Text013: Label 'there is no product %1 pending of Liquidate';
        Selected: Boolean;
        Text014: Label 'Vendor cant be empty';
        Text015: Label 'Quanity (Base) Exchange (%1) to liquidate cant be higher in Purch. Invoice (%2). Item %3';
        _Text006: Label 'Vendor %1';
        _Text008: Label 'Document %1 alredy exists for vendor %2';
        _Text009: Label 'Error Item setup %1, Unit Cost cant be zero.';
        _Text010: Label 'Done!.Return To Vendor %1 registered.';
        _Text011: Label 'There must be at least one record selected';
        _Text012: Label 'Item %1 is no associate to vendor %2';
        _Text013: Label 'User must be assignment to store %1';
        Vendor: Record "vendor";
        ItemVendor: Record "Item Vendor";
        UPDExchange: Record "FSN POS Exchange Transaction";
        Store: Record "LSC Store";
        Text016: Label 'Liquidate product. Exchange';
        Text017: Label 'Exchange Transac. %1 alrealy document Link Entry  No. %2';
        Text018: Label 'Vendor %1 is not permited liquidate tipo Credit Note';
        Sign: Decimal;
        PagePrintDocument: Page "FSN Documents Rcvd. Posted";
        UnblockDocumentType: Boolean;
        GlobalPermitedInsertCreditNote: Boolean;
        Text019: Label 'You have pending Require: %1 , Item %2';
        CountRows: Integer;
        Text020: Label 'Item barcode %1 not found';
        _Text001: Label 'Relation Hist. Invoice No. %1, Order No. %2, Vendor Invoice No. %3';
        MessageSet: Text[100];
        Text021: Label 'Mode liquidate invalid.\ Product %1 \Recovery Mode Setup is %2';

    procedure ValidatePurchaseInvoice(Text2: Text[20])
    var
        PurchInvLines_l: Record "Purch. Inv. Line";
        PurchInvHeader_l: Record "Purch. Inv. Header";
        UnitOfMeasure_l: Record "Item Unit of Measure";
        ItemExists: Boolean;
        ItemTmp: Record "Item" temporary;
    begin
        IF Text2 <> '' THEN BEGIN
            PurchInvHeader_l.GET(Text2);//WVILLALTA04DIC19-
            VendorSelect := PurchInvHeader_l."Buy-from Vendor No.";
            ItemTmp.RESET;
            ItemTmp.DELETEALL;
            Rec.RESET;
            Rec.FIND('-');
            REPEAT
                IF NOT ItemTmp.GET(Rec."Item No.") THEN BEGIN
                    ItemTmp.INIT();
                    ItemTmp."No." := Rec."Item No.";
                    ItemTmp."LSC Qty. per Base Comp. Unit" := 0;
                    ItemTmp.INSERT();
                END;
                IF UnitOfMeasure_l.GET(Rec."Item No.", Rec."Unit of Measure") THEN
                    ItemTmp."LSC Qty. per Base Comp. Unit" += Quantity * UnitOfMeasure_l."Qty. per Unit of Measure"
                ELSE
                    ItemTmp."LSC Qty. per Base Comp. Unit" += Quantity;
                ItemTmp.MODIFY();

            UNTIL Rec.NEXT = 0;

            ItemTmp.FIND('-');
            REPEAT
                PurchInvLines_l.RESET;
                PurchInvLines_l.SETCURRENTKEY("Document No.", "Line No.");
                PurchInvLines_l.SETRANGE(PurchInvLines_l."Document No.", Text2);
                PurchInvLines_l.SETRANGE(PurchInvLines_l."No.", ItemTmp."No.");
                PurchInvLines_l.CALCSUMS(PurchInvLines_l."Quantity (Base)");
                IF PurchInvLines_l."Quantity (Base)" < ItemTmp."LSC Qty. per Base Comp. Unit" THEN
                    ERROR(STRSUBSTNO(Text015, ItemTmp."LSC Qty. per Base Comp. Unit", PurchInvLines_l."Quantity (Base)", GetItemDescription(ItemTmp."No.")));

            UNTIL ItemTmp.NEXT = 0;
            //END;
        END ELSE//WVILLALTA04DIC19+
            ERROR(Text004);
    end;

    procedure DocumentTypeOnValidate()
    begin
        CASE DocumentoType_ OF
            DocumentoType_::ItemOnly:
                BEGIN
                    ExtDocAndAmtVisible := FALSE;
                    SearchPurchReceiptVisible := FALSE;
                    OtherDescrptionVisible := FALSE;
                    OtherDescriptionTypeDoc := '';
                    SearchPurchReceipt := '';
                END;
            DocumentoType_::CreditNote:
                BEGIN
                    ExtDocAndAmtVisible := TRUE;
                    SearchPurchReceiptVisible := FALSE;
                    OtherDescrptionVisible := FALSE;
                    SearchPurchReceipt := '';
                END;
            DocumentoType_::Purch_Receipt:
                BEGIN
                    ExtDocAndAmtVisible := TRUE;
                    SearchPurchReceiptVisible := TRUE;
                    OtherDescrptionVisible := FALSE;
                END;
            DocumentoType_::Other:
                BEGIN
                    ExtDocAndAmtVisible := TRUE;
                    SearchPurchReceiptVisible := FALSE;
                    OtherDescrptionVisible := TRUE;
                    SearchPurchReceipt := '';
                END;
        END;
    end;

    procedure CreateDocumentEntryLink(pLiquidateProductByProduct: Boolean; pType: Integer)
    var
        ExternalDocuments: Record "FSN Document Received Entry";
        ExternalDocuments2: Record "FSN Document Received Entry";
        ExternalDocumentDiscLoc: Record "FSN Document Rcvd. Location";
        FasaniPurchSetup_l: Record "FSN Fasani Setup";
        NoSeriesMgt: Codeunit "NoSeriesManagement";
        SerieCodeSelect: Code[20];
        GlobalTemporary: Record "FSN Global Table Temporary" temporary;
        Counter: Integer;
        EntryNext: Integer;
        CostAmount: Decimal;
        Item_l: Record "Item";
        VATPostingSetup: Record "VAT Posting Setup";
        POSExSetup: Record "FSN POS Exchange Setup";
    begin
        //WVILLALTA04DIC19-
        IF GlobalPermitedInsertCreditNote THEN
            FasaniPurchSetup_l.GET("Store No.")
        ELSE
            FasaniPurchSetup_l.GET(UserLS."Store No.");
        SerieCodeSelect := NoSeriesMgt.GetNextNo(FasaniPurchSetup_l."No. Serie Exchange Receipt", TODAY, TRUE);

        IF pType = 0 THEN
            ExternalDoc_ := SerieCodeSelect;

        IF NOT GlobalPermitedInsertCreditNote THEN
            IF (pType = 1) AND NOT Vendor."FSN Allowed Credit Note Exch." THEN
                ERROR(STRSUBSTNO(Text018, Vendor.Name));

        ExternalDocuments2.RESET;
        ExternalDocuments2.SETCURRENTKEY("External Document No.", "Customer No. Related", "Vendor No.", Status);
        ExternalDocuments2.SETRANGE(ExternalDocuments2."External Document No.", ExternalDoc_);
        ExternalDocuments2.SETRANGE(ExternalDocuments2."Vendor No.", VendorSelect);
        ExternalDocuments2.SETRANGE(ExternalDocuments2.Status, ExternalDocuments2.Status::Posted);
        IF ExternalDocuments2.FINDFIRST THEN
            ERROR(STRSUBSTNO(_Text008, ExternalDocuments2."External Document No.", Vendor.Name));

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

        Rec.RESET;
        Rec.FIND('-');
        REPEAT
            UPDExchange.GET(Rec."Receipt No.", Rec."Transaction No.", Rec."Line No.", Rec."Store No.", Rec."POS Terminal No.");

            IF NOT GlobalPermitedInsertCreditNote THEN
                IF UPDExchange."Store No." <> UserLS."Store No." THEN
                    ERROR(STRSUBSTNO(_Text013, UPDExchange."Store No."));

            POSExSetup.GET(UPDExchange."POS Exchange No.");//WVILLALTA 8.20-
            IF POSExSetup."Type Recovery" = POSExSetup."Type Recovery"::CreditNote THEN BEGIN
                IF DocumentoType_ <> DocumentoType_::CreditNote THEN
                    ERROR(STRSUBSTNO(Text021, UPDExchange.GetItemDescription(UPDExchange."Item No."), FORMAT(POSExSetup."Type Recovery")));
            END ELSE BEGIN
                IF POSExSetup."Type Recovery" = POSExSetup."Type Recovery"::Product THEN
                    IF NOT (DocumentoType_ IN [DocumentoType_::ItemOnly, DocumentoType_::Purch_Receipt]) THEN
                        ERROR(STRSUBSTNO(Text021, UPDExchange.GetItemDescription(UPDExchange."Item No."), FORMAT(POSExSetup."Type Recovery")));
            END;                                                 //WVILLALTA 8.20+

            IF UPDExchange.Request = UPDExchange.Request::DeliveryToVendor THEN
                ERROR(STRSUBSTNO(Text019, FORMAT(UPDExchange.Request), UPDExchange.GetItemDescription(UPDExchange."Item No.")));
            IF NOT ItemVendor.GET(VendorSelect, UPDExchange."Item No.", '') THEN
                ERROR(STRSUBSTNO(_Text012, UPDExchange.GetItemDescription(UPDExchange."Item No."), Vendor.Name));

            IF UPDExchange."Document Receipt Key 2" > 0 THEN
                ERROR(STRSUBSTNO(Text016, UPDExchange."Receipt No.", FORMAT(UPDExchange."Document Receipt Key 2")));

            IF GlobalPermitedInsertCreditNote THEN
                IF UPDExchange.Status <> UPDExchange.Status::"Request Liquidate CN" THEN
                    ERROR(STRSUBSTNO(Text003, FORMAT(UPDExchange.Status), UPDExchange."Receipt No."));

            IF NOT GlobalPermitedInsertCreditNote THEN
                IF NOT (UPDExchange.Status IN
                  [UPDExchange.Status::"Exit Applied", UPDExchange.Status::"Liquidate Product", UPDExchange.Status::"Liquidate CreditNote"]) THEN
                    ERROR(STRSUBSTNO(Text003, FORMAT(UPDExchange.Status), UPDExchange."Receipt No."));

            UPDExchange."External Document No." := '';
            UPDExchange."Amount Doc. Inc. VAT" := 0;
            IF pType <> 0 THEN BEGIN
                UPDExchange."External Document No." := ExternalDoc_;
                UPDExchange."Amount Doc. Inc. VAT" := AmtExternalDoc_;
            END;

            UPDExchange."Process Message" := MessageSet;

            IF pLiquidateProductByProduct THEN
                UPDExchange.Status := UPDExchange.Status::"Liquidate Product"
            ELSE
                UPDExchange.Status := UPDExchange.Status::"Liquidate CreditNote";

            UPDExchange."Document Receipt Key 1" := ExternalDocuments."User ID";
            UPDExchange."Document Receipt Key 2" := EntryNext;
            UPDExchange.MODIFY;
            Counter += 1;
            CostAmount += ROUND(UPDExchange."Unit Cost" * UPDExchange.Quantity, 0.01, '=');
            Store.GET(UPDExchange."Store No.");
            Store.TESTFIELD("Location Code");
            Item_l.GET(UPDExchange."Item No.");
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
            GlobalTemporary.Decimal_1 += ROUND(UPDExchange."Unit Cost" * UPDExchange.Quantity, 0.01, '=');
            VATPostingSetup.RESET;
            CLEAR(VATPostingSetup);
            IF Vendor."VAT Bus. Posting Group" <> '' THEN
                VATPostingSetup.GET(Vendor."VAT Bus. Posting Group", Item_l."VAT Prod. Posting Group")
            ELSE
                VATPostingSetup.GET(Item_l."VAT Bus. Posting Gr. (Price)", Item_l."VAT Prod. Posting Group");

            IF VATPostingSetup."VAT Prod. Posting Group" <> '' THEN
                GlobalTemporary.Decimal_2 += (ROUND(UPDExchange."Unit Cost" * UPDExchange.Quantity, 0.01, '=') *
                    (VATPostingSetup."VAT %" / 100))
            ELSE
                GlobalTemporary.Decimal_2 += 0;

            GlobalTemporary.MODIFY();
            Rec := UPDExchange;
            Rec.MODIFY;
        UNTIL Rec.NEXT = 0;
        IF Counter = 0 THEN
            ERROR(_Text011);

        Sign := 1;
        ExternalDocuments."Entry Posted No." := EntryNext;
        ExternalDocuments."Entry Type" := ExternalDocuments."Entry Type"::Purchase;
        IF pLiquidateProductByProduct THEN
            ExternalDocuments."Document Type" := ExternalDocuments."Document Type"::Receipt
        ELSE BEGIN
            ExternalDocuments."Document Type" := ExternalDocuments."Document Type"::"Credit Note";
            Sign := -1;
        END;

        ExternalDocuments."Group Type" := ExternalDocuments."Group Type"::Exchange;
        ExternalDocuments."External Document No." := ExternalDoc_;
        ExternalDocuments."Date Document" := TODAY;
        ExternalDocuments.Comment := Text016;
        ExternalDocuments."Vendor No." := VendorSelect;
        ExternalDocuments."Posting Date" := TODAY;
        ExternalDocuments.Status := ExternalDocuments.Status::Posted;
        ExternalDocuments."Order No. Related" := '';
        ExternalDocuments."Customer No. Related" := '';
        ExternalDocuments."(Order) Invoice No." := '';
        ExternalDocuments."Document Type Text" := FORMAT(ExternalDocuments."Document Type");
        ExternalDocuments.Description := STRSUBSTNO(_Text006, Vendor.Name);
        ExternalDocuments."VAT Prod. Posting Group" := '';
        ExternalDocuments."Store LS Retail" := UserLS."Store No.";
        ExternalDocuments."Reference Key" := SerieCodeSelect;
        ExternalDocuments.INSERT(TRUE);

        IF GlobalTemporary.FIND('-') THEN
            REPEAT
                ExternalDocumentDiscLoc."Document Entry No." := EntryNext;
                ExternalDocumentDiscLoc."Location Code" := GlobalTemporary.Code10_1;
                ExternalDocumentDiscLoc."Net Amount" := GlobalTemporary.Decimal_1;
                ExternalDocumentDiscLoc."Net Amount" := ExternalDocumentDiscLoc."Net Amount" * Sign;
                ExternalDocumentDiscLoc."VAT Amount" := ROUND(GlobalTemporary.Decimal_2, 0.01, '=');
                ExternalDocumentDiscLoc."VAT Amount" := ExternalDocumentDiscLoc."VAT Amount" * Sign;
                ExternalDocumentDiscLoc."Total Amount" := GlobalTemporary.Decimal_1 + ROUND(GlobalTemporary.Decimal_2, 0.01, '=');
                ExternalDocumentDiscLoc."Total Amount" := ExternalDocumentDiscLoc."Total Amount" * Sign;
                ExternalDocumentDiscLoc."% Distribution" := ROUND(ExternalDocumentDiscLoc."Net Amount" / CostAmount, 0.001, '=') * 100;
                ExternalDocumentDiscLoc."Type Distribution" := ExternalDocumentDiscLoc."Type Distribution"::"Suggest by System";
                ExternalDocumentDiscLoc."Posting Date" := TODAY;
                ExternalDocumentDiscLoc."Document Date" := TODAY;
                ExternalDocumentDiscLoc.INSERT(TRUE);
            UNTIL GlobalTemporary.NEXT = 0;
        Rec.DELETEALL;
        COMMIT;
        PagePrintDocument.PrintDocument(ExternalDocuments);
        //WVILLALTA04DIC19+
    end;

    procedure SetTemporaryRecord(ExchangeRec: Record "FSN POS Exchange Transaction"; pUnblockDocumentType: Boolean)
    begin
        //WVILLALTA04DIC19-
        UnblockDocumentType := pUnblockDocumentType;
        DocumentTypeOnValidate;
        GlobalPermitedInsertCreditNote := FALSE;

        IF ExchangeRec.Status = ExchangeRec.Status::"Exit Applied" THEN BEGIN
            Rec.RESET;
            Rec.INIT();
            Rec := ExchangeRec;
            Rec.INSERT();
        END;
        //WVILLALTA04DIC19+
    end;

    procedure SetTemporaryCreditNote(pStatus: Integer; pExternalDocument: Text[50]; pAmountMax: Decimal; pUnblockDocumentType: Boolean; pCountRows: Integer)
    var
        Exchanges: Record "FSN POS Exchange Transaction";
    begin
        //WVILLALTA04DIC19-
        UnblockDocumentType := pUnblockDocumentType;
        DocumentoType_ := 1;
        ExternalDoc_ := pExternalDocument;
        AmtExternalDoc_ := pAmountMax;
        DocumentTypeOnValidate;
        GlobalPermitedInsertCreditNote := TRUE;

        Rec.RESET;
        Rec.DELETEALL;

        Exchanges.RESET;
        Exchanges.SETCURRENTKEY(Status, "Transfer Order No.");
        Exchanges.SETRANGE(Exchanges.Status, Exchanges.Status::"Request Liquidate CN");
        Exchanges.SETRANGE(Exchanges."External Document No.", pExternalDocument);
        IF Exchanges.FIND('-') THEN
            REPEAT
                Rec.INIT();
                Rec := Exchanges;
                Rec.INSERT();
            UNTIL Exchanges.NEXT = 0;
        //WVILLALTA04DIC19+
    end;
}

