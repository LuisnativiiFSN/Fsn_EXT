/*page 50087 "FSN Sell Out Process"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    Editable = true;

    layout
    {
        area(content)
        {
            field("POS Terminal No"; terminal)
            {
                Caption = 'POS Terminal No.';
            }
            field("Transaction No In"; TransInit)
            {
                Caption = 'Transaction No Inicial';
            }
            field("Transaction No Fin"; TransFin)
            {
                Caption = 'Transaction No Fin';
            }
        }
    }


    actions
    {
        area(Processing)
        {
            action(Apply)
            {
                ApplicationArea = All;
                Image = Apply;

                trigger OnAction()
                var
                    SellOutValue: Codeunit "FSN Sell Out Value Entries";
                begin
                    SellOutValue.ProcesSellOut(terminal, TransInit, TransFin);
                    clear(terminal);
                    clear(TransInit);
                    clear(TransFin);
                end;
            }
        }
    }
    var
        terminal: Code[10];
        TransInit: Integer;
        TransFin: Integer;
}*/


