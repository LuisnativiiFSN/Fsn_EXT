page 50080 "FASANI Stock Request"
{
    Caption = 'FSN Stock Request';
    PageType = Document;
    SourceTable = "LSC InStore Stock Req. Header";
    SourceTableView = SORTING(Status, "Store No.")
                      WHERE(Status = CONST(Open));

    layout
    {
        area(content)
        {
            group(General)
            {
                Caption = 'General';
                field("No."; "No.")
                {
                    ApplicationArea = All;

                    Editable = false;
                }
                field("Store No."; "Store No.")
                {
                    ApplicationArea = All;
                }
                field("Document Date"; "Document Date")
                {
                    ApplicationArea = All;
                }
                field(Status; Status)
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Req. Status"; "Req. Status")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Reference Type"; "Reference Type")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("Reference No."; "Reference No.")
                {
                    ApplicationArea = All;
                    Editable = false;
                }
                field("InStoreFunc.GetStockReqDocNo(Rec)"; InStoreFunc.GetStockReqDocNo(Rec))
                {
                    ApplicationArea = All;
                    Caption = 'InStore Reference No.';
                    Editable = false;

                    trigger OnDrillDown()
                    var
                        InStoreDocNo: Code[20];
                        InStoreHeader: Record "LSC InStore Header";
                        InStoreHeaderForm: Page "LSC InStore Document";
                    begin
                        InStoreDocNo := InStoreFunc.GetStockReqDocNo(Rec);
                        if InStoreHeader.Get(InStoreDocNo) then begin
                            Clear(InStoreHeaderForm);
                            InStoreHeader.SetRecFilter();
                            InStoreHeaderForm.SetTableView(InStoreHeader);
                            InStoreHeaderForm.RunModal();
                        end;
                    end;
                }
            }
            part(Control1100409010; "LSC Stock Request Subform")
            {
                ApplicationArea = All;
                SubPageLink = "Document No." = FIELD("No.");
            }
            group("Assign To")
            {
                Caption = 'Assign To';
                group(DocumentType)
                {
                    Caption = 'Document Type';
                    field("Document Type"; "Document Type")
                    {
                        ApplicationArea = All;
                        ValuesAllowed = "Purchase Order", "Transfer Order";

                        trigger OnValidate()
                        begin
                            if "Document Type" = "Document Type"::"Transfer Order" then
                                TransferOrderDocumentTypeOnVal;
                            if "Document Type" = "Document Type"::"Purchase Order" then
                                PurchaseOrderDocumentTypeOnVal;
                        end;
                    }
                }
                group(PurchaseOrderDeliveryLocation)
                {
                    Caption = 'Purchase Order Delivery Location';
                    Visible = PurchaseOrderDeliveryLocationV;
                    field("Plan.Stock Demand Type"; "Plan.Stock Demand Type")
                    {
                        ApplicationArea = All;
                        ValuesAllowed = "PO to Store", "PO to Whse w/X-Dock";
                    }
                }
                group(ProcessType)
                {
                    Caption = 'Process Type';
                    field("Process Type"; "Process Type")
                    {
                        ApplicationArea = All;
                        ValuesAllowed = Create, Replenish;

                        trigger OnValidate()
                        begin
                            if "Process Type" = "Process Type"::Replenish then
                                ReplenishProcessTypeOnValidate;
                            if "Process Type" = "Process Type"::Create then
                                CreateProcessTypeOnValidate;
                        end;
                    }
                }
                group(PurchaseOrder)
                {
                    Caption = 'Purchase Order';
                    Visible = PurchaseOrderVisible;
                    field("Vendor No."; "Vendor No.")
                    {
                        ApplicationArea = All;
                    }
                }
                group(TransferOrder)
                {
                    Caption = 'Transfer Order';
                    Visible = TransferOrderVisible;
                    field("From Store No."; "From Store No.")
                    {
                        ApplicationArea = All;
                    }
                    field("In-Transit Code"; "In-Transit Code")
                    {
                        ApplicationArea = All;
                    }
                }
            }
        }
    }

    actions
    {
        area(navigation)
        {
            group("&Stock Req.")
            {
                Caption = '&Stock Req.';
                separator(Action1100409043)
                {
                }
                action("&Reference Document")
                {
                    ApplicationArea = All;
                    Caption = '&Reference Document';
                    Image = Entries;

                    trigger OnAction()
                    var
                        PurchaseHeader: Record "Purchase Header";
                        PurchInvHeader: Record "Purch. Inv. Header";
                        TransferHeader: Record "Transfer Header";
                        TransRcptHeader: Record "Transfer Receipt Header";
                    begin
                        if "Reference Type" > 0 then
                            if "Reference Type" = "Reference Type"::Purchase then begin
                                if PurchaseHeader.Get(PurchaseHeader."Document Type"::Order, "Reference No.") then
                                    PAGE.Run(10000815, PurchaseHeader)
                                else begin
                                    PurchInvHeader.Reset();
                                    PurchInvHeader.SetCurrentKey(PurchInvHeader."Order No.");
                                    PurchInvHeader.SetRange("Order No.", "Reference No.");
                                    if PurchInvHeader.Find('-') then
                                        PAGE.Run(138, PurchInvHeader);
                                end;
                            end else begin
                                if TransferHeader.Get("Reference No.") then
                                    PAGE.Run(10001010, TransferHeader)
                                else begin
                                    TransRcptHeader.Reset();
                                    TransRcptHeader.SetCurrentKey("Transfer Order No.");
                                    TransRcptHeader.SetRange("Transfer Order No.", "Reference No.");
                                    if TransRcptHeader.Find('-') then
                                        PAGE.Run(5745, TransRcptHeader);
                                end;
                            end;
                    end;
                }
                action("&Validate Inventory")
                {
                    ApplicationArea = All;
                    Caption = '&Validate Inventory';
                    Image = AddWatch;
                    Promoted = true;
                    PromotedIsBig = true;
                    PromotedCategory = Process;
                    trigger OnAction()
                    begin
                        ValidateInventory();
                    end;
                }
            }
        }
        area(processing)
        {
            group("F&unctions")
            {
                Caption = 'F&unctions';
                action("&Send Request")
                {
                    ApplicationArea = All;
                    Caption = '&Send Request';
                    Image = SendApprovalRequest;
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    begin
                        InStoreMgt.SendStockReqDocReq(Rec);
                        if InStoreFunc.GetStockReqDocNo(Rec) <> '' then
                            Status := Status::Closed;
                        "Req. Status" := "Req. Status"::Sent;
                        Rec.Modify();
                    end;
                }
                separator(Action1100409026)
                {
                }
                action("&Decline Request")
                {
                    ApplicationArea = All;
                    Caption = '&Decline Request';
                    Image = Reject;
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    begin
                        if Confirm(Text001, true) then begin
                            StockReqMgt.DeclineStockReq(Rec);
                        end;
                    end;
                }
                action("&Assign Request")
                {
                    ApplicationArea = All;
                    Caption = '&Assign Request';
                    Image = Delegate;
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    var
                        ItemVendor: Record "Item Vendor";
                        InStoreStockReqLine: Record "LSC InStore Stock Req. Line";
                        Error000: Label 'El producto %1 no se encuentra relacionado con el proveedor %2 en Item Vendor';

                    begin
                        if not ValidateNotRepeatProducts() then begin
                            Message(Text003);
                            exit;
                        end;

                        if Rec."Document Type" = Rec."Document Type"::"Purchase Order" then begin
                            InStoreStockReqLine.Reset();
                            InStoreStockReqLine.SetRange(InStoreStockReqLine."Document No.", Rec."No.");
                            if InStoreStockReqLine.Find('-') then
                                repeat
                                    if not ItemVendor.Get(Rec."Vendor No.", InStoreStockReqLine."Item No.") then
                                        Error(StrSubstNo(Error000, InStoreStockReqLine."Item No.", Rec."Vendor No."));
                                until InStoreStockReqLine.Next() = 0;
                        end;

                        if Confirm(Text002, true) then begin
                            if "Process Type" = "Process Type"::Create then begin
                                if "Document Type" = "Document Type"::"Purchase Order" then begin
                                    TestField("Vendor No.");
                                    StockReqMgt.CreatePurchasOrder(Rec, "Vendor No.")
                                end else begin
                                    TestField("From Store No.");
                                    TestField("In-Transit Code");
                                    StockReqMgt.CreateTransferOrder(Rec, "From Store No.");
                                end;
                            end else
                                StockReqMgt.CreatePlannedStockDemand(Rec);
                        end;
                    end;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        UpdateForm;
    end;

    trigger OnInit()
    begin
        PurchaseOrderVisible := true;
        PurchaseOrderDeliveryLocationV := true;
        TransferOrderVisible := true;
    end;

    trigger OnNewRecord(BelowxRec: Boolean)
    begin
        InitRecord();
    end;

    trigger OnOpenPage()
    var
        lFilterGroup: Integer;
    begin
        lFilterGroup := FilterGroup;
        FilterGroup(10);
        RetailUser.Get(UserId);
        if RetailUser."Store No." <> '' then
            SetRange("Store No.", RetailUser."Store No.")
        else
            SetRange("Store No.");
        FilterGroup(lFilterGroup);
    end;

    var
        RetailUser: Record "LSC Retail User";
        InStoreMgt: Codeunit "LSC InStore Mgt";
        InStoreFunc: Codeunit "LSC InStore Functions";
        StockReqMgt: Codeunit "LSC InStore Stock Req Mgt";
        ErrorText: Text;
        [InDataSet]
        TransferOrderVisible: Boolean;
        [InDataSet]
        PurchaseOrderDeliveryLocationV: Boolean;
        [InDataSet]
        PurchaseOrderVisible: Boolean;
        Text001: Label 'Decline stock req.';
        Text002: Label 'Assign stock req.';
        Text003: Label 'Cannot be validate Because a product has been entered multiple times.';



    [Scope('OnPrem')]
    procedure InitRecord()
    var
        Store: Record "LSC Store";
    begin
        if not Store.Get(RetailUser."Store No.") then
            exit;
        "Store No." := Store."No.";
    end;

    [Scope('OnPrem')]
    procedure UpdateForm()
    begin


        if "Document Type" = "Document Type"::"Purchase Order" then begin
            if "Process Type" = "Process Type"::Create then begin
                TransferOrderVisible := false;
                PurchaseOrderDeliveryLocationV := false;
                PurchaseOrderVisible := true;
            end else begin
                PurchaseOrderVisible := false;
                TransferOrderVisible := false;
                PurchaseOrderDeliveryLocationV := true;
            end;
        end else begin
            if "Process Type" = "Process Type"::Create then begin
                PurchaseOrderVisible := false;
                PurchaseOrderDeliveryLocationV := false;
                TransferOrderVisible := true;
            end else begin
                PurchaseOrderVisible := false;
                TransferOrderVisible := false;
                PurchaseOrderDeliveryLocationV := false;
            end;
        end;
    end;

    local procedure ValidateInventory()
    var
        Item: Record Item;
        TransferLine: Record "Transfer Line";
        InventoryLevel: Record "FSN WMS Levels";
        RequestLines: Record "LSC InStore Stock Req. Line";
        DecimalRead: Decimal;
        RecordExists: Boolean;
        ExitForValidation: Boolean;
        lText001: Label 'Status must be "Send".';
        lText002: Label 'Quantity cant be f zero. Item %1 Line %2';
        lText003: Label 'Items barcode %1 - %2 is empty';
        lText004: Label 'Inventory is not enough for: \-> Item %1 Line %2 \-> Qty. Request %3 - Inventory Logistic Warehouse %4. Diff = %5';
        lText005: Label 'Barcode %1 - %2 is not Match , Inventory cant be evaluated';
        lText006: Label 'Warning! \-> Item %1 \-> Request quantity %2 + all Requests %3 is higher to Inventory Logistic Warehouse %4. Diff = %5 ';
        lText007: Label 'Inventory validated sucessfull!!';
    begin
        if not ValidateNotRepeatProducts() then begin
            Message(Text003);
            exit;
        end;



        if not ("Req. Status" = "Req. Status"::Sent) then begin
            Message(lText001);
            exit;
        end;

        Clear(ExitForValidation);

        RequestLines.Reset();
        RequestLines.SetRange("Document No.", "No.");
        if RequestLines.Find('-') then
            repeat
                if RequestLines.Quantity = 0 then begin
                    ErrorText := StrSubstNo(lText002, RequestLines.Description, RequestLines."Line No.");
                    ExitForValidation := true;
                end;

                Clear(RecordExists);
                Clear(DecimalRead);

                if Item.Get(RequestLines."Item No.") then;

                if Item."FSN Barcode No." = '' then
                    Error(StrSubstNo(lText003, Item."No.", Item.Description));

                if InventoryLevel.Get(RequestLines."Item No.") then begin
                    DecimalRead := InventoryLevel.InventoryCD;
                    RecordExists := true;
                end;

                if RecordExists then begin
                    if RequestLines.Quantity > DecimalRead then begin
                        ErrorText := StrSubstNo(lText004, RequestLines.Description, RequestLines."Line No.", Format(RequestLines.Quantity), Format(DecimalRead), Format(DecimalRead - RequestLines.Quantity));
                        ExitForValidation := true;
                    end;
                end else begin
                    ErrorText := StrSubstNo(lText005, RequestLines."FSN Barcode No.", RequestLines.Description);
                    ExitForValidation := true;
                end;

                if not ExitForValidation then begin
                    TransferLine.Reset();
                    TransferLine.SetRange("Transfer-from Code", 'CD');
                    TransferLine.SetRange("Item No.", RequestLines."Item No.");
                    TransferLine.SetRange("Quantity Shipped", 0);
                    TransferLine.CalcSums(Quantity);
                    if (TransferLine.Quantity + RequestLines.Quantity) > DecimalRead then begin
                        ErrorText := StrSubstNo(lText006, RequestLines.Description, Format(RequestLines.Quantity), Format(TransferLine.Quantity), Format(DecimalRead), Format(DecimalRead - RequestLines.Quantity - TransferLine.Quantity));
                        Message(ErrorText);
                    end;
                end;
            until (RequestLines.Next() = 0) or ExitForValidation;

        if ExitForValidation then
            Message(ErrorText)
        else
            Message(lText007);
    end;

    local procedure ValidateNotRepeatProducts(): Boolean
    var
        RequestLines: Record "LSC InStore Stock Req. Line";
        RequestLines2: Record "LSC InStore Stock Req. Line";
    begin
        RequestLines.Reset();
        RequestLines.SetRange("Document No.", Rec."No.");
        if RequestLines.Find('-') then
            repeat
                RequestLines2.Reset();
                RequestLines2.SetRange("Document No.", Rec."No.");
                RequestLines2.SetRange("Item No.", RequestLines."Item No.");
                if RequestLines2.Find('-') then
                    if RequestLines2.Count() > 1 then
                        exit(false);
            until RequestLines.Next() = 0;
        exit(true);
    end;

    local procedure PurchaseOrderDocumentTypeOnVal()
    begin
        UpdateForm;
    end;

    local procedure TransferOrderDocumentTypeOnVal()
    begin
        UpdateForm;
    end;

    local procedure CreateProcessTypeOnValidate()
    begin
        UpdateForm;
    end;

    local procedure ReplenishProcessTypeOnValidate()
    begin
        UpdateForm;
    end;
}
