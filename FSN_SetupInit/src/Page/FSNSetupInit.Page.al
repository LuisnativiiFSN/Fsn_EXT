page 50088 "FSN Setup Init"
{
    Caption = 'FSN Setup Init';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "FSN Parameter";
    SourceTableTemporary = true;
    layout
    {
        area(Content)
        {
            repeater(Parameters)
            { 	
                field(Grupo; Rec.Grupo)
                {
                    ApplicationArea = All;
                }
                field(Codigo; Rec.Codigo)
                {
                    ApplicationArea = All;
                }
                field("New Value"; Rec."Value Text 1")
                {
                    Caption = 'New Value';
                    ApplicationArea = All;
                }
                field(Master; Rec.Activo)
                {
                    Caption = 'Master';
                    ApplicationArea = All;
                }
                field(Reference; Rec."Value Text 2")
                {
                    Caption = 'Reference';
                    ApplicationArea = All;
                }
                field("Rank CREF"; Rec.Descripcion)
                {
                    Caption = 'Rank CREF / Name';
                    ApplicationArea = All;
                    Description = 'initial value..Final value';

                }
                field("Rank FAC"; Rec.Valor)
                {
                    Caption = 'Rank FAC / direction';
                    ApplicationArea = All;
                    Description = 'initial value..Final value';
                }
                field("Rank TICKET"; Rec."String Parameters 1 Json")
                {
                    Caption = 'Rank TICKET / zipcode&city';
                    ApplicationArea = All;
                    Description = 'initial value..Final value';
                }
                field("Rank NOCRE"; Rec."String Parameters 2 Json")
                {
                    Caption = 'Rank NOCRE / phone';
                    ApplicationArea = All;
                    Description = 'initial value..Final value';
                }
            }
        }

    }

    actions
    {
        area(Processing)
        {
            action("LS Retail Init")
            {
                ApplicationArea = All;

                trigger OnAction()
                var
                    SetUpInit: Codeunit "FSN Setup Init";
                begin
                    if Confirm('Initialize Retail?') then begin
                        SetUpInit.DeleteProcress('LSC');
                        Message('LS Retail Inititialized');
                    end;
                end;
            }
            action("Delete All")
            {
                ApplicationArea = All;

                trigger OnAction()
                var
                    SetUpInit: Codeunit "FSN Setup Init";
                begin
                    if Confirm('Delete All?') then begin
                        SetUpInit.DeleteProcress('ALL');
                        Message('All deleted');
                    end;
                end;
            }
            action("Create New Terminal")
            {
                ApplicationArea = All;
                trigger OnAction()
                var
                    SetUpInit: Codeunit "FSN Setup Init";
                begin
                    SetUpInit.CreateNewTPV(Rec);

                end;
            }
            action(test)
            {
                ApplicationArea = All;
                trigger OnAction()
                var
                    SetUpInit: Codeunit "FSN Setup Init";
                begin
                    SetUpInit.Test();
                end;
            }
        }
    }
    trigger OnOpenPage()
    begin
        Rec.Init();
        Rec.Grupo := 'TPV';
        Rec.Codigo := 'TPVNUEVO';
        Rec.Insert();
        Rec.Grupo := 'TIENDA';
        Rec.Codigo := 'TIENDA NO.';
        Rec.Insert();

    end;

}