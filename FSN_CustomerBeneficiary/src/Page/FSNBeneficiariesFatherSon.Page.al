page 50046 "FSN Beneficiaries Father/Son"
{
    PageType = List;
    Caption = 'FSN Beneficiaries Father/Son';
    SourceTable = "FSN Benef. Father Son";
    ApplicationArea = all;
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Customer No."; "Customer No.")
                {
                }
                field("Card No."; "Card No.")
                {
                }
                field(Name; Name)
                {
                }
                field(mail; mail)
                {
                    Caption = 'Mail';
                }
                field(Relation; Relation)
                {
                }
                field(Poliza; Poliza)
                {
                }
                field(Titular; Titular)
                {
                }
            }
        }
    }

    actions
    {
    }
}

