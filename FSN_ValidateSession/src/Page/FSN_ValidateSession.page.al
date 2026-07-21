page 50103 "FSN Validate Session Remision"
{
    PageType = Card;
    UsageCategory = Administration;
    ApplicationArea = All;
    RefreshOnActivate = true;
    SourceTable = "LSC Staff";
    SourceTableTemporary = true;
    DeleteAllowed = false;
    InsertAllowed = false;
    SaveValues = true;
    Caption = 'Usuario para recepcion';
    PromotedActionCategories = 'Processing';

    layout
    {
        area(Content)
        {
            group(GroupName)
            {
                Caption = 'Login';
                field(user; user)
                {
                    ApplicationArea = All;
                    Caption = 'Usuario';
                    trigger OnValidate()
                    var
                        myInt: Integer;

                    begin
                        VEmpleados();
                    end;

                }
                field(Password; Password)
                {
                    ApplicationArea = All;
                    ExtendedDatatype = Masked;
                    Caption = 'Contraseña';
                    trigger OnValidate()
                    var
                        myInt: Integer;

                    begin
                        ValCredencial
                    end;
                }

            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Save)
            {
                ApplicationArea = All;
                Caption = 'GUARDAR USUARIO';
                Image = Save;
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                trigger OnAction()
                begin
                    if Pass then begin
                        POSSESION.SetValue('VSESSION', VEmpleado.ID);
                        CurrPage.Close();
                    end else
                        Message('El campo contraseña no debe estar vacío');
                end;
            }
        }
    }

    var
        myInt: Integer;
        user: Code[10];
        Password: Text;
        POSSESION: Codeunit "LSC POS Session";
        VEmpleado: Record "LSC Staff";
        Pass: Boolean;

    procedure VEmpleados()
    var
    begin
        if user <> '' then begin
            VEmpleado.Reset();
            if VEmpleado.Get(user) then begin
            end else
                Error('Empleado no registrado');
        end;
    end;

    procedure ValCredencial()
    var
        myInt: Integer;
    begin
        if VEmpleado.Get(user) then begin
            if not VEmpleado.IsPassWordValid(Password) then
                Error('Contraseña incorrecta')
            else
                Pass := true;
        end;
    end;

    trigger OnClosePage()
    var
        myInt: Integer;
    begin
        user := '';
        Password := '';
        Pass := false;
        ClearAll();
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    begin
        if (POSSESION.GetValue('VSESSION') = '') and ((user <> '') and (Password <> '')) then begin
            ValCredencial();
            if Pass then
                POSSESION.SetValue('VSESSION', VEmpleado.ID);
        end;
    end;
}
