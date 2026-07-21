page 50088 "FSN Purchase Setup Manager"
{
    PageType = StandardDialog;
    RefreshOnActivate = false;
    ApplicationArea = ALL;
    UsageCategory = Administration;
    SourceTable = "FSN Fasani Setup";
    Caption = 'Configuración de compra de Fasani';

    layout
    {
        area(content)
        {
            field(storeSelected; StoreSelected)
            {
                Caption = 'Sucursal';
                DrillDown = false;
                TableRelation = "FSN Fasani Setup" WHERE("Store No." = FILTER(<> 'CD'));
                trigger OnValidate()
                begin
                    Rec.RESET;
                    IF StoreSelected <> 'CD' THEN BEGIN
                        Rec.SETFILTER("Store No.", '=%1', StoreSelected);
                        IF Rec.FIND('-') THEN BEGIN
                            StoreSelected := Rec."Store No.";
                        END
                        ELSE
                            MESSAGE(TEXT0001, StoreSelected);

                    END
                    ELSE
                        ;
                end;
            }
            field("Use Check Transfer"; "Use Check Transfer")
            {
                Caption = 'Bloqueo Transferencias Antiguas';

                trigger OnValidate()
                var
                    MinutesToAdd: Duration;
                begin
                    IF NOT "Use Check Transfer" THEN
                        IF "Minutes Unlocking" <> 0 THEN BEGIN
                            MinutesToAdd := "Minutes Unlocking" * 60000; // 1 minuto = 60,000 ms
                            "Next Datetime Lock" := CURRENTDATETIME + MinutesToAdd;
                        END;
                end;
            }
            field("Exchange Block/Request"; "Exchange Block/Request")
            {
                Caption = 'Bloqueo Canje Sin Entregar';
            }
            field("Exchange Block/Auth."; "Exchange Block/Auth.")
            {
                Caption = 'Bloqueo Canje Sin Autorizacion';
            }
            /*field("Minutes Unlocking"; "Minutes Unlocking")
            {
                Editable = false;
            }
            field("Next Datetime Lock"; "Next Datetime Lock")
            {
                Editable = false;
            }*/
        }
    }

    actions
    {
    }

    trigger OnOpenPage()
    begin

        Rec.SETFILTER("Store No.", '<>%1', 'CD');
        IF Rec.FINDFIRST THEN BEGIN
            Rec.GET(Rec."Store No.");
            StoreSelected := Rec."Store No.";
        END
        ELSE
            MESSAGE(TEXT0001, StoreSelected);
    end;

    var
        StoreSelected: Code[10];
        TEXT0001: Label 'La sucursal "%1" no existe en la tabla "Fasani Purchase Setup".';
}

