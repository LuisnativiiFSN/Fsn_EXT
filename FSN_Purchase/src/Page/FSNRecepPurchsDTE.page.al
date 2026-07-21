/*page 50123 "FSN Recep. Purchs. DTE"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "FSN Recep. Purch. DTE";

    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                field("No."; "No.")
                {
                    ApplicationArea = All;
                    Editable = true;
                }
                field("VAT Registration No."; "VAT Registration No.")
                {
                    ApplicationArea = All;
                    //Editable = false;
                }
                field("Purchase No."; "Purchase No.")
                {
                    ApplicationArea = All;
                }
                field("FSN Consolidate No."; "FSN Consolidate No.")
                {
                    ApplicationArea = All;
                    //Editable = false;
                }
                field("Location Code"; "Location Code")
                {
                    ApplicationArea = All;
                    //Editable = false;
                }
                field("DTE AuthNumber"; "DTE AuthNumber")
                {
                    ApplicationArea = All;
                    //Editable = false;
                }
                field("DTE Invoice"; "DTE Invoice")
                {
                    ApplicationArea = All;
                    //Editable = false;
                }
                field("Signature Validation"; "Signature Validation")
                {
                    ApplicationArea = All;
                    //Editable = false;
                }
                field(Subtotal; Subtotal)
                {
                    ApplicationArea = All;
                    //Editable = false;
                }
                field(IVA; IVA)
                {
                    ApplicationArea = All;
                    //Editable = false;
                }
                field(Total; Total)
                {
                    ApplicationArea = All;
                    //Editable = false;
                }
            }
        }
        area(Factboxes)
        {

        }
    }

    actions
    {
        area(Processing)
        {
            action(ActionName)
            {
                ApplicationArea = All;

                trigger OnAction();
                begin

                end;
            }
        }
    }
}*/