page 50101 "FSN Calle Reparto"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    SourceTable = "LSC Delivery Street";

    layout
    {
        area(Content)
        {
            grid(Buscador)
            {
                field(Filtro; Filtro)
                {
                    ApplicationArea = All;
                    Caption = 'Buscar Calle';
                    trigger OnValidate()
                    begin
                        Rec.SetFilter("Street Name", '*' + Filtro + '*');
                        CurrPage.Update(false);
                    end;
                }
            }
            repeater(GroupName)
            {
                field("Street Name"; "Street Name")
                {
                    ApplicationArea = All;
                    Caption = 'Nombre Calle';
                }
                field("Post Code"; "Post Code")
                {
                    ApplicationArea = All;
                    Caption = 'Codigo postal';
                }
                field("Address 2"; "Address 2")
                {
                    ApplicationArea = All;
                    Caption = 'Ciudad';
                }
                field(City; City)
                {
                    ApplicationArea = All;
                    Caption = 'Departamento';
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
    var
        Filtro: Text[60];

    local procedure MyProcedure()
    var
        myInt: Integer;
    begin

    end;
}