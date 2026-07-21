table 50046 "FSN Fecha Auxiliar"
{

    fields
    {
        field(1; ID; Integer)
        {
            AutoIncrement = false;
        }
        field(5; Mes; Option)
        {
            Caption = 'Month';
            OptionMembers = " ",Enero,Febrero,Marzo,Abril,Mayo,Junio,Julio,Agosto,Septiembre,Octubre,Noviembre,Diciembre;

            trigger OnValidate()
            begin

                ValidarMesAnio();
            end;
        }
        field(10; Anio; Integer)
        {
            Caption = 'Year';

            trigger OnValidate()
            begin

                ValidarMesAnio();
            end;
        }
    }

    keys
    {
        key(Key1; ID)
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
    }

    trigger OnInsert()
    begin

        ValidarMesAnio();
    end;

    trigger OnModify()
    begin

        ValidarMesAnio();
    end;

    procedure ValidarMesAnio()
    begin

        IF Mes = Mes::" " THEN
            CASE DATE2DMY(TODAY, 2) OF
                1:
                    Mes := Mes::Enero;
                2:
                    Mes := Mes::Febrero;
                3:
                    Mes := Mes::Marzo;
                4:
                    Mes := Mes::Abril;
                5:
                    Mes := Mes::Mayo;
                6:
                    Mes := Mes::Junio;
                7:
                    Mes := Mes::Julio;
                8:
                    Mes := Mes::Agosto;
                9:
                    Mes := Mes::Septiembre;
                10:
                    Mes := Mes::Octubre;
                11:
                    Mes := Mes::Noviembre;
                12:
                    Mes := Mes::Diciembre;
            END;

        IF Anio = 0 THEN
            Anio := DATE2DMY(TODAY, 3);
    end;
}

