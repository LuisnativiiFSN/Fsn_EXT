page 50112 "FSN Ajuste Trans. sales Lote"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "Item Ledger Entry";
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    layout
    {
        area(Content)
        {
            repeater(GroupName)
            {
                field("Lot No."; "Lot No.")
                {
                    Editable = false;
                    trigger OnValidate()
                    var
                        myInt: Integer;
                    begin
                        CurrPage.Update(false);
                    end;
                }
                field("Expiration Date"; "Expiration Date")
                {
                    Editable = false;
                }
                field("Item No."; "Item No.")
                {
                    Editable = false;
                }
                field("Location Code"; "Location Code")
                {
                    Editable = false;
                }
                field("Posting Date"; "Posting Date")
                {
                    Editable = false;
                }
                field(Open; Open)
                {
                    Editable = false;
                }
                field(Quantity; Quantity)
                {
                    Visible = false;
                    Editable = false;
                }
                field("Invoiced Quantity"; "Invoiced Quantity")
                {
                    Visible = false;
                    Editable = false;
                }
                field("Remaining Quantity"; "Remaining Quantity")
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

    trigger OnAfterGetRecord()
    var
        lOldFilterGroup: Integer;
    begin
        SetRange("Item No.", Rec."Item No.");
        SetRange("Location Code", Rec."Location Code");
        SetFilter("Lot No.", '<>%1&<>%2', GlobalLot, '');
        SetRange(Open, true);
        FilterGroup(10); // Establece un grupo de filtros no editable por el usuario
    end;


    trigger OnInit()
    var
        myInt: Integer;
    begin
        SetRange("Item No.", Rec."Item No.");
        SetRange("Location Code", Rec."Location Code");
        SetFilter("Lot No.", '<>%1&<>%2', GlobalLot, '');
        SetRange(Open, true);
        FilterGroup(10);
    end;

    var
        GlobalLot: Code[50];


    procedure GlobalLote(Lot_No: Code[50]);
    var
        myInt: Integer;
    begin
        GlobalLot := Lot_No;
    end;

    trigger OnClosePage()
    var
        myInt: Integer;
    begin
        GlobalLot := '';
    end;
}