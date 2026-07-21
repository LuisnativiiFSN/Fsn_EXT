page 50042 "FSN POS Posted Exch. Transac."
{

    Caption = 'POS Posted Exchange Transac.';
    Editable = false;
    PageType = List;
    SourceTable = "POS Posted Exchange Trans.";
    ApplicationArea = All;
    UsageCategory = Lists;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Receipt No."; "Receipt No.")
                {
                }
                field("Transaction No."; "Transaction No.")
                {
                }
                field("Line No."; "Line No.")
                {
                }
                field("Barcode No."; "Barcode No.")
                {
                }
                field("Item No."; "Item No.")
                {
                }
                field("Unit of Measure"; "Unit of Measure")
                {
                }
                field(ItemDescription; GetItemDescription("Item No."))
                {
                    Caption = 'Description';
                }
                field(Quantity; Quantity)
                {
                    Style = Strong;
                    StyleExpr = TRUE;
                }
                field(AttribCode; "Attrib 1 Code")
                {
                    Caption = 'AttribCode';
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
                }
                field("POS Terminal No."; "POS Terminal No.")
                {
                }
                field(Status; Status)
                {
                    StyleExpr = SetTextStyle;
                }
                field("Transfer Order No."; "Transfer Order No.")
                {
                }
                field("Staff ID"; "Staff ID")
                {
                }
                field("Sales Staff"; "Sales Staff")
                {
                }
                field("Customer No."; "Customer No.")
                {
                }
                field("Transaction Date"; "Transaction Date")
                {
                }
                field("POS Exchange No."; "POS Exchange No.")
                {
                }
                field("Posting Date"; "Posting Date")
                {
                }
                field("Use Inventory"; "Use Inventory")
                {
                }
                field(Complete; Complete)
                {
                }
                field("Process Message"; "Process Message")
                {
                }
                field("External Document No."; "External Document No.")
                {
                }
                field("Amount Doc. Inc. VAT"; "Amount Doc. Inc. VAT")
                {
                }
                field("Transfer-to Code"; "Transfer-to Code")
                {
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

    trigger OnAfterGetRecord()
    var
        Item_l: Record "Item";
        Vendor_l: Record "vendor";
    begin
        IF "Item No." <> '' THEN BEGIN
            IF Item_l.GET("Item No.") THEN BEGIN
                ItemAttrib1Code := Item_l."LSC Attrib 1 Code";
                IF Item_l."Vendor No." <> '' THEN
                    IF Vendor_l.GET(Item_l."Vendor No.") THEN
                        ItemPrimaryVendor := Vendor_l.Name;
            END;
        END;
        CostAmount := "Unit Cost" * Quantity;
        CASE Status OF
            Status::"Liquidated Product":
                SetTextStyle := 'StrongAccent';
            Status::"Liquidated CreditNote":
                SetTextStyle := 'AttentionAccent';
        END;
    end;

    trigger OnOpenPage()
    var
        UserRetail: Record "LSC Retail User";
    begin
        IF UserRetail.GET(USERID) THEN
            IF UserRetail."Store No." <> '' THEN BEGIN
                FILTERGROUP(2);
                SETRANGE("Store No.", UserRetail."Store No.");
                FILTERGROUP(0);
            END;
    end;

    var
        SetTextStyle: Text[50];
        ItemAttrib1Code: Text[50];
        ItemPrimaryVendor: Text[50];
        CostAmount: Decimal;
        DocumentRegisterPage: Page "FSN Documents Rcvd. Posted";
}

