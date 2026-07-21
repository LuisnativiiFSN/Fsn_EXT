page 50115 "Sales Quotes by store"
{
    Caption = 'Cuotas por tienda';
    PageType = List;
    SourceTable = "Sales Quotes";
    UsageCategory = Administration;
    DataCaptionFields = "Store No.";

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(Year; Rec.Year)
                {
                    Caption = 'Año';
                }
                field(Month; Rec.Month)
                {
                    Caption = 'Mes';
                }
                field("Store No."; Rec."Store No.")
                {
                    TableRelation = "LSC Store"."No.";
                    Caption = 'Tienda';
                }
                field(Type; Rec.Type)
                {
                    MultiLine = true;
                    Caption = 'Tipo';
                }
                field(Total; Rec.Total)
                {
                }
            }
        }
        area(factboxes)
        {
            systempart(Notes; Notes)
            {

            }
            systempart(Links; Links)
            {
            }
        }
    }

    actions
    {
    }

    trigger OnAfterGetRecord()
    var
        myInt: Integer;
    begin

    end;
}

