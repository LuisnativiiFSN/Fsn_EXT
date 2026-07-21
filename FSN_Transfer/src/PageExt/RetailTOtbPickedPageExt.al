pageextension 50033 "FSN Retail TO. tb. Picked" extends "LSC Retail TO. tb. Picked"
{
    layout
    {
        addafter("Buyer Group Code")
        {
            field("External Document No."; "External Document No.")
            {
                ApplicationArea = All;
                Editable = false;
                Caption = 'Nº documento externo';
                ToolTip = 'Nº documento externo';
            }
        }
    }

    actions
    {
        addafter(Statistics)
        {
            action(Scanner)
            {
                ApplicationArea = All;
                Caption = 'Scanner';
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                Image = BarCode;
                trigger OnAction()
                var
                    PageScanner: Page "FSN Transfer Scanner";
                begin
                    Clear(PageScanner);
                    PageScanner.SetPurchOrderNo(Rec."No.");
                    PageScanner.RunModal();
                end;
            }
        }
    }

    var
        myInt: Integer;
}