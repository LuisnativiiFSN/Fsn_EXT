page 50060 "FSN Payments Retail Rol Center" //60018 - 50101
{
    PageType = RoleCenter;
    Caption = 'Payments Retail Role Center';
    layout
    {
        area(rolecenter)
        {
        }
    }

    actions
    {
        area(processing)
        {
            action(Vouchers)
            {
                Image = Voucher;
                RunObject = Page "FSN POS Card Providers Mgt";
            }


            action(CardAction)
            {
                Caption = 'Entradas de tarjeta POS';
                ApplicationArea = All;
                Image = Card;
                RunObject = Page "FSN POS Card Request Entries";

            }

        }
    }

}


