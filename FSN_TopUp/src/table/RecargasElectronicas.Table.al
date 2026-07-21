table 50040 "FSN Recargas Electronicas"
{

    fields
    {
        field(1; "Transaction No."; Integer)
        {
            /* TableRelation = "LSC Transaction Header"."Transaction No." where("Store No." = field("Store No."),
                                                                           "POS Terminal No." = field("POS Terminal No."));*/
            DataClassification = CustomerContent;
            Caption = 'Transaction No.', comment = 'ESP="No. transacción"';
        }
        field(2; "Line No."; Integer)
        {
            Caption = 'Line No.', comment = 'ESP="No. linea"';
            DataClassification = CustomerContent;
            trigger OnValidate()
            var
                RecargaElectronica: Record "FSN Recargas Electronicas";
            begin
                RecargaElectronica.SETCURRENTKEY("Store No.", "POS Terminal No.", "Receipt No.");
                IF RecargaElectronica.FINDLAST THEN
                    Rec."Line No." := RecargaElectronica."Line No." + 1
                ELSE
                    Rec."Line No." := 1;
            end;

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
        field(6; "Staff ID"; Code[20])
        {
            Caption = 'Staff', comment = 'ESP="Empleado"';
            DataClassification = CustomerContent;
        }
        field(7; "Numero Telefono"; Text[50])
        {
            Caption = 'Phone number', comment = 'ESP="Número teléfono"';
            DataClassification = CustomerContent;
        }
        field(8; "Monto Recarga"; Decimal)
        {
            Caption = 'Recharge amount', comment = 'ESP="Monto recarga"';
            DataClassification = CustomerContent;
        }
        field(9; Operador; Text[50])
        {
            Caption = 'Operador', comment = 'ESP="Operador"';
            DataClassification = CustomerContent;
        }
        field(10; Fecha; Date)
        {
            Caption = 'Date', comment = 'ESP="Fecha"';
            DataClassification = CustomerContent;
        }
        field(11; Hora; Time)
        {
            Caption = 'Hour', comment = 'ESP="Hora"';
            DataClassification = CustomerContent;
        }
        field(12; Estado; Text[1])
        {
            Caption = 'State', comment = 'ESP="Estado"';
            DataClassification = CustomerContent;
        }
        field(13; "Fecha Recarga"; DateTime)
        {
            Caption = 'Recharge date', comment = 'ESP="Fecha recarga"';
            DataClassification = CustomerContent;
        }
        field(14; "Transaccion Operador"; Text[50])
        {
            Caption = 'Operator transaction', comment = 'ESP="Transaccion operador"';
            DataClassification = CustomerContent;
        }
        field(15; "Respuesta Servicio"; Text[100])
        {
            Caption = 'Response Service', comment = 'ESP="Respuesta servicio"';
            DataClassification = CustomerContent;
        }
        field(16; "Monto Debitado"; Decimal)
        {
            Caption = 'Amount Debited', comment = 'ESP="Monto Debitado"';
            DataClassification = CustomerContent;
        }
        field(17; "Monto Acreditado"; Decimal)
        {
            Caption = 'Amount Credited', comment = 'ESP="Monto Acreditado"';
            DataClassification = CustomerContent;
        }
        field(18; CESC; Decimal)
        {
            Caption = 'CESC', comment = 'ESP="CESC"';
            DataClassification = CustomerContent;
        }
        field(19; "Comision Debitada O"; Decimal)
        {
            Caption = 'Commission Debited O', comment = 'ESP="Comisión debitada O"';
            DataClassification = CustomerContent;
        }
        field(20; "Comision Aplicada O"; Decimal)
        {
            Caption = 'Applied Commission O', comment = 'ESP="Comisión aplicada O"';
            DataClassification = CustomerContent;
        }
        field(21; "Comision Debitada D"; Decimal)
        {
            Caption = 'Commission Debited D', comment = 'ESP="Comisión debitada D"';
            DataClassification = CustomerContent;
        }
        field(22; "Comision Aplicada D"; Decimal)
        {
            Caption = 'Applied Commission D', comment = 'ESP="Comisión aplicada D"';
            DataClassification = CustomerContent;
        }
        field(23; "Monto Disponible"; Decimal)
        {
            Caption = 'Amount available', comment = 'ESP="Monto disponible"';
            DataClassification = CustomerContent;
        }
        field(24; "Tipo Paquete"; Text[150])
        {
            Caption = 'Package Tigo', comment = 'ESP="Paquete Tigo"';
            DataClassification = CustomerContent;
        }
        field(25; Replicated; Boolean)
        {
            Caption = 'Replicated', comment = 'ESP="Replicado"';
            DataClassification = CustomerContent;
        }
        field(26; "Replication Counter"; Integer)
        {
            Caption = 'Replication Counter', comment = 'ESP="Contador replicación"';
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                RecargaElectronica: Record "FSN Recargas Electronicas";
            begin
                RecargaElectronica.SETCURRENTKEY("Store No.", "POS Terminal No.", "Receipt No.");
                IF RecargaElectronica.FINDLAST THEN
                    Rec."Replication Counter" := RecargaElectronica."Replication Counter" + 1
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
    }

    trigger OnInsert()
    var
    begin
        VALIDATE("Replication Counter");
        VALIDATE("Line No.");
    end;

    trigger OnModify()
    begin
        //VALIDATE("Replication Counter");
    end;
}

