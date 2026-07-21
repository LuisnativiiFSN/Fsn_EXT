pageextension 50041 "FSN SALES QUOTES" extends "LSC Store Card"
{
    layout
    {
        // Add changes to page layout here
    }

    actions
    {
        // Add changes to page actions here
        addafter("&Hourly Sales")
        {
            action("Cuotas Sala")
            {
                Caption = 'Cuotas sala';
                Image = Quote;
                Promoted = true;
                PromotedCategory = Category4;
                PromotedIsBig = true;
                ApplicationArea = All;
                RunObject = page "Sales Quotes by store";
                RunPageLink = "Store No." = field("No.");
                Visible = true;
            }
        }
    }

    var
        myInt: Integer;

}