table 50041 "FSN Recargas Electr. Hist."
{

    fields
    {
        field(1; "Transaction No."; Integer)
        {
            DataClassification = CustomerContent;
            Caption = 'Transaction No.', comment = 'ESP="No. transacción"';
            /* TableRelation = "LSC Transaction Header"."Transaction No." where("Store No." = field("Store No."),
                                                                           "POS Terminal No." = field("POS Terminal No."));*/
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.', comment = 'ESP="No. linea"';
            DataClassification = CustomerContent;
            /* trigger OnValidate()
            var
                RecargaHist: Record "FSN Recargas Electr. Hist.";
            begin
                RecargaHist.SETCURRENTKEY("Store No.", "POS Terminal No.", "Receipt No.");
                IF RecargaHist.Find('+') THEN
                    Rec."Line No." := RecargaHist."Line No." + 1
                ELSE
                    Rec."Line No." := 1;
            end; */
        }
        field(3; "Store No."; Code[10])
        {
            Caption = 'Store No.', comment = 'ESP="No. tienda"';
            DataClassification = CustomerContent;
        }
        field(4; "POS Terminal No."; Code[10])
        {
            Caption = 'POS Terminal No.', comment = 'ESP="No. terminal"';
            DataClassification = CustomerContent;
        }
        field(5; "Receipt No."; Code[20])
        {
            Caption = 'Receipt No.', comment = 'ESP="No. recibo"';
            DataClassification = CustomerContent;
        }
        field(6; "Intento No."; Integer)
        {
            Caption = 'Attempts', comment = 'ESP="Intentos"';
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                RecargaElectronicaHistorica: Record "FSN Recargas Electr. Hist.";
            begin
                Rec."Intento No." := 1;
                RecargaElectronicaHistorica.SETCURRENTKEY("Store No.", "POS Terminal No.", "Receipt No.", "Line No.");
                RecargaElectronicaHistorica.SetRange("Store No.", Rec."Store No.");
                RecargaElectronicaHistorica.SetRange("POS Terminal No.", Rec."POS Terminal No.");
                RecargaElectronicaHistorica.SetRange("Receipt No.", Rec."Receipt No.");
                RecargaElectronicaHistorica.SetRange("Numero Telefono", Rec."Numero Telefono");
                IF RecargaElectronicaHistorica.FindLast() THEN
                    Rec."Intento No." := RecargaElectronicaHistorica."Intento No." + 1
            end;

        }
        field(7; "Staff ID"; Code[20])
        {
            Caption = 'Staff', comment = 'ESP="Empleado"';
            DataClassification = CustomerContent;
        }
        field(8; "Numero Telefono"; Text[20])
        {
            Caption = 'Phone number', comment = 'ESP="Número Teléfono"';
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                Text001: Label 'CONFIRMAR NÚMERO DE TELÉFONO \';
            begin

                IF "Numero Telefono" = '' THEN
                    "Numero Telefono" := '666';
                MODIFY(true);
            end;
        }
        field(9; "Monto Recarga"; Decimal)
        {
            Caption = 'Recharge amount', comment = 'ESP="Monto recarga"';
            DataClassification = CustomerContent;
        }
        field(10; Operador; Text[50])
        {
            Caption = 'Operador', comment = 'ESP="Operador"';
            DataClassification = CustomerContent;
        }
        field(11; Fecha; Date)
        {
            Caption = 'Date', comment = 'ESP="Fecha"';
            DataClassification = CustomerContent;
        }
        field(12; Hora; Time)
        {
            Caption = 'Hour', comment = 'ESP="Hora"';
            DataClassification = CustomerContent;
        }
        field(13; "Fecha Recarga"; DateTime)
        {
            Caption = 'Date recharge', comment = 'ESP="Fecha recarga"';
            DataClassification = CustomerContent;
        }
        field(14; Observacion; Text[250])
        {
            Caption = 'Remark', comment = 'ESP="Observación"';
            DataClassification = CustomerContent;
        }
        field(15; "Control ID"; Integer)
        {
            Caption = 'Control', comment = 'ESP="Control"';
            DataClassification = CustomerContent;
        }
        field(16; "Tipo Paquete"; Text[150])
        {
            Caption = 'Package Tipo', comment = 'ESP="Paquete Tigo"';
            DataClassification = CustomerContent;
        }
        field(17; Replicated; Boolean)
        {
            Caption = 'Replicated', comment = 'ESP="Replicado"';
            DataClassification = CustomerContent;
        }
        field(18; "Replication Counter"; Integer)
        {
            Caption = 'Replication Counter', comment = 'ESP="Contador replicación"';
            DataClassification = CustomerContent;
            trigger OnValidate()
            var
                RecargaElectronicaHist: Record "FSN Recargas Electr. Hist.";
            begin
                RecargaElectronicaHist.SETCURRENTKEY("Store No.", "POS Terminal No.", "Receipt No.");
                IF RecargaElectronicaHist.FindLast() THEN
                    Rec."Replication Counter" := RecargaElectronicaHist."Replication Counter" + 1
                ELSE
                    Rec."Replication Counter" := 1;
            end;
        }
    }

    keys
    {
        key(Key1; "Store No.", "POS Terminal No.", "Receipt No.")
        {
            Clustered = true;
        }
        key(Key2; "Replication Counter")
        {
        }
        key("Intento No."; "Intento No.")
        {

        }
    }


    trigger OnInsert()
    begin
        VALIDATE("Replication Counter");
        //VALIDATE("Intento No.");
        //VALIDATE("Line No.");
    end;


    trigger OnModify()
    begin
        VALIDATE("Replication Counter");
        VALIDATE("Intento No.");
    end;
}

