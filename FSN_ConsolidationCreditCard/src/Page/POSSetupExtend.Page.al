page 50064 "FSN POS Setup Extend" //50028
{
    Caption = 'POS Setup Extend';
    PageType = List;
    SourceTable = "FSN POS Setup Extend";

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(Type; Type)
                {
                    Editable = TypeEditable;
                }
                field("Line Type"; "Line Type")
                {
                }
                field("From Date"; "From Date")
                {
                }
                field("Value No."; "Value No.")
                {
                }
                field("Line No."; "Line No.")
                {
                }
                field("Store No."; "Store No.")
                {
                }
                field("To Date"; "To Date")
                {
                }
                field("Value Reference No."; "Value Reference No.")
                {
                }
                field("POS Terminal No."; "POS Terminal No.")
                {
                }
                field("Data Extra 1"; "Data Extra 1")
                {
                }
                field("Data Extra 2"; "Data Extra 2")
                {
                }
            }
        }
    }

    actions
    {
    }

    trigger OnInit()
    begin
        TypeEditable := TRUE;
    end;

    var
        TypeEditable: Boolean;


    procedure FilterAdminCard()
    begin
        FILTERGROUP(2);
        SETRANGE(Type, Type::CardManager);
        TypeEditable := FALSE;
        FILTERGROUP(0);
    end;
}

