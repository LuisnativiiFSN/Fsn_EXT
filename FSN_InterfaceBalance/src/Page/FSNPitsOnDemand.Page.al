page 50107 "FSN PITS On Demand"
{
    PageType = StandardDialog;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = 50045;
    Caption = 'Generar PITS Ventas';
    layout
    {
        area(content)
        {

            field("Starting_Date"; "Starting Date")
            {
                Caption = 'Fecha Inicio';
                trigger OnValidate()
                begin
                    IF "Starting Date" > TODAY THEN
                        ERROR('Error. No se puede introducir una fecha en el futuro');
                end;
            }
            field("Ending_Date"; "Ending Date")
            {
                Caption = 'Fecha Final';
                trigger OnValidate()
                begin
                    IF "Ending Date" > TODAY THEN
                        ERROR('Error. No se puede introducir una fecha en el futuro');
                end;
            }
            field("Store"; "Store")
            {
                Caption = 'Sala';
                TableRelation = "LSC Store";
            }
            field("ReCreate"; "Re-CReate")
            {
                Caption = 'Recrear Registros';
            }

        }
    }

    actions
    {
    }

    VAR
        "Starting Date": Date;
        "Ending Date": Date;
        Store: Code[10];
        RegisterPITSSales: Codeunit "FSN Register PITS Sales";
        "Re-Create": Boolean;
        TransHeader: Record "LSC Transaction Header";
        PITSSales: Record "FSN PITS_ventas";

    trigger OnClosePage()
    var

    begin
        "Re-Create" := FALSE;
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var
        Farmacias: Record "LSC Store";
    begin
        IF NOT "Re-Create" THEN BEGIN
            IF (("Starting Date" = 0D) XOR ("Ending Date" = 0D)) THEN
                ERROR('Introduzca ambas fechas o deje los campos vacios para usar el dia anterior')
            ELSE
                IF ("Starting Date" <> 0D) AND ("Ending Date" <> 0D) THEN
                    RegisterPITSSales.FillTable("Starting Date", "Ending Date", Store)
                ELSE
                    IF (("Starting Date" = 0D) AND ("Ending Date" = 0D)) AND (Store <> '') THEN BEGIN
                        MESSAGE('Se realizara el calculo para la fecha %1', CALCDATE('<-2D>'));
                        RegisterPITSSales.FillTable(0D, 0D, Store)
                    END;
        END
        ELSE BEGIN
            //IF (("Starting Date" = 0D) OR ("Ending Date" = 0D) OR (Store = '')) THEN // CSALX20161220 Multitiendas
            IF (("Starting Date" = 0D) OR ("Ending Date" = 0D)) THEN
                MESSAGE('Para Recrear datos todos los campos fechas son requeridos')
            ELSE BEGIN
                //IF ("Starting Date" <> 0D) AND ("Ending Date" <> 0D) AND (Store <> '') THEN BEGIN // CSALX20161220 Multitiendas
                IF ("Starting Date" <> 0D) AND ("Ending Date" <> 0D) THEN BEGIN
                    IF CONFIRM('¨Esta seguro de recrear los datos con la informacion especificada?') THEN BEGIN
                        PITSSales.RESET;
                        PITSSales.SETRANGE(FECHA_DOCUMENTO, "Starting Date", "Ending Date");
                        IF Store <> '' THEN
                            PITSSales.SETRANGE(SUCURSAL, Store);
                        PITSSales.DELETEALL;

                        /* JH19072024-2 Se eliminaran los datos
                        TransHeader.RESET;
                        TransHeader.SETRANGE(Date, "Starting Date", "Ending Date");
                        IF Store <> '' THEN
                            TransHeader.SETRANGE("Store No.", Store);
                        //TransHeader.MODIFYALL(Registered, FALSE); //JH290520247
                        */
                        IF Store <> '' THEN BEGIN
                            RegisterPITSSales.FillTable("Starting Date", "Ending Date", Store);
                        END ELSE BEGIN
                            Farmacias.RESET;
                            IF Farmacias.FIND('-') THEN
                                REPEAT
                                    TransHeader.RESET;
                                    TransHeader.SETRANGE(Date, "Starting Date", "Ending Date");
                                    TransHeader.SETRANGE("Store No.", Farmacias."No.");
                                    IF TransHeader.FIND('-') THEN
                                        RegisterPITSSales.FillTable("Starting Date", "Ending Date", Farmacias."No.");
                                UNTIL Farmacias.NEXT <= 0;
                        END;
                        MESSAGE('Se recrearon los datos satisfactoriamente');
                    END
                    ELSE
                        MESSAGE('Proceso Cancelado');
                END;
            END;
        END;
    end;
}

