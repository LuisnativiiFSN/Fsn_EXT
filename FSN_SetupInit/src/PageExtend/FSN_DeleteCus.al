pageextension 50083 "FSN Delete Customer" extends "Config. Package Subform"
{
    layout
    {
    }

    actions
    {
        // Add changes to page actions here
        addafter("F&unctions")
        {
            action("Eliminar")
            {
                ApplicationArea = Basic, Suite;
                Image = Delete;
                trigger OnAction()
                var
                    ConfigPackage: Record "Config. Package";
                    ConfigPackageMgt: Codeunit "Config. Package Management";
                    ConfigPackageTable: Record "Config. Package Table";
                begin
                    if Gparameter() then begin
                        if Rec."Table ID" = Tabla then
                            POSSESION.SetValue('CUSTOMERDEL', 'TRUE');

                        CurrPage.SetSelectionFilter(ConfigPackageTable);
                        if Confirm(SingleTableSelectedQst, true) then begin
                            ConfigPackage.Get("Package Code");
                            ConfigPackageMgt.ApplyPackage(ConfigPackage, ConfigPackageTable, true);
                            POSSESION.SetValue('CUSTOMERDEL', '');
                        end;
                    end;
                end;
            }
        }
    }

    var
        myInt: Integer;
        Parameter: Record "FSN Parameter";
        Tabla: Integer;
        POSSESION: Codeunit "LSC POS Session";
        SingleTableSelectedQst: Label 'Desea Eliminar los registros de clientes?';


    procedure GParameter(): Boolean
    var
        myInt: Integer;
    begin
        if (parameter.Get('ELIMINAR', 'P_CONF')) and (Parameter.Activo) then begin
            Evaluate(Tabla, Parameter.Valor);
            exit(true)
        end else
            exit(false);
    end;
}