page 50048 "FSN POSTrans Line"
{
    PageType = ListPart;
    Editable = false;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "LSC POS Trans. Line";
    Caption = 'Lineas en ventas';
    //SourceTableTemporary = true;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field(Number; Number)
                {
                    Editable = false;
                }
                field(Descripcion; Description)
                {
                    Editable = false;
                    Style = Attention;
                    StyleExpr = (Rec."Entry Type" = Rec."Entry Type"::FreeText);
                }
                field(Quantity; Quantity)
                {
                    Editable = false;
                }
                field(Amount; Amount)
                {
                    Editable = false;
                }
                field(Inventario; InventoryValue)
                {
                    Editable = false;
                    Caption = 'Inventario';
                    Style = Strong;
                    StyleExpr = 'StrongAccent';
                }
                field("Store No."; "Store No.")
                {
                    Editable = false;
                }

            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ActionName)
            {
                ApplicationArea = All;

                trigger OnAction()
                begin

                end;
            }
        }
    }

    var
        Globals: Record "LSC POS Trans. Line";
        DeliveryFE: Codeunit "FSN Delivery Functions Extend";
        InventoryValue: Text;


    trigger OnOpenPage()
    var
        myInt: Integer;
        pRecRef: RecordRef;
        POSSESSION: Codeunit "LSC POS Session";
    begin
        FILTERGROUP(2);
        SETRANGE("Receipt No.", POSSESSION.GetValue('CURRORDER'));
        SETRANGE("Entry Status", "Entry Status"::" ");
        FILTERGROUP(0);
        Validate("Option Value Text");
    end;

    trigger OnAfterGetRecord()
    var
        pRecRef: RecordRef;
    begin
        pRecRef.GetTable(Rec);
        InventoryValue := DeliveryFE.GetInventoryUM(pRecRef);

    end;

    procedure SETGLOBALVALUE(PosTransLine: Record "LSC POS Trans. Line")
    begin
        Globals := PosTransLine;
    end;
}
