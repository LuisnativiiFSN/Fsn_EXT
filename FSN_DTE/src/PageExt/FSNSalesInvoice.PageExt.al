pageextension 50134 "FSN Sales Invoice" extends "Sales Invoice"
{
    layout
    {
        addafter(SubType)
        {
            field("DTE AuthNumber"; Rec."DTE AuthNumber")
            {
                ApplicationArea = All;
                Editable = BlockVending;
            }
            field("DTE Invoice"; Rec."DTE Invoice")
            {
                ApplicationArea = All;
                Editable = BlockVending;
            }
            field("Signature Validation"; Rec."Signature Validation")
            {
                ApplicationArea = All;
                Editable = BlockVending;
            }
            field(LocationCode; Rec."Location Code")
            {
                ApplicationArea = All;
                Caption = 'Cod. Almacen';
                Editable = BlockVending;
            }
        }
        addbefore("Sell-to Contact No.")
        {
            field("VAT Registration No."; Rec."VAT Registration No.")
            {
                ApplicationArea = All;
            }
        }
    }


    trigger OnOpenPage()
    var
        FSNUtility: Codeunit "FSN Utility";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        Processed: Boolean;
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        ErrorMessage: text;
    begin
        Processed := false;
        RequestID := 'VENDINGVAL';
        XMLRequest := Rec."No.";
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, ErrorMessage);

        if Processed then
            BlockVending := false
        ELSE
            BlockVending := true;
    end;

    var
        BlockVending: Boolean;
}