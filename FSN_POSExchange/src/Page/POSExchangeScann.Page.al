page 50041 "FSN POS Exchange Scann"
{

    Caption = 'POS Exchange Scann';
    DelayedInsert = true;
    DeleteAllowed = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    PageType = List;
    ShowFilter = false;
    SourceTable = "FSN POS Exchange Transaction";
    ApplicationArea = All;
    UsageCategory = Administration;


    layout
    {
        area(content)
        {
            repeater(General)
            {
                field("Receipt No."; "Receipt No.")
                {
                }
                field("Line No."; "Line No.")
                {
                }
                field("Transaction Date"; "Transaction Date")
                {
                }
                field("Item No."; "Item No.")
                {
                }
                field("Unit of Measure"; "Unit of Measure")
                {
                }
                field(Quantity; Quantity)
                {
                }
                field(ItemDescription; GetItemDescription("Item No."))
                {
                    Caption = 'Item Description';
                }
                field("Store No."; "Store No.")
                {
                }
                field(Status; Status)
                {
                }
                field("Sales Staff"; "Sales Staff")
                {
                }
                field("POS Exchange No."; "POS Exchange No.")
                {
                }
                field("Vendor Document No."; "Vendor Document No.")
                {
                }
                field(Request; Request)
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
    }

    trigger OnClosePage()
    begin
        GlobalRECSelection := Rec;
    end;

    trigger OnOpenPage()
    begin
        CLEAR(GlobalRECSelection);
    end;

    var
        GlobalRECSelection: Record "FSN POS Exchange Transaction";

    procedure GetSelection(var RecSelect: Record "FSN POS Exchange Transaction")
    begin
        RecSelect := GlobalRECSelection;
    end;
}

