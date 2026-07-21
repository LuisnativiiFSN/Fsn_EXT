page 50079 "FSN Recargas Historico"
{
    PageType = List;
    Caption = 'History Recharges', comment = 'ESP="Histórico Recargas"';
    SourceTable = "FSN Recargas Electr. Hist.";
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Transaction No."; "Transaction No.")
                {
                    Caption = 'Transaction No.', comment = 'ESP="No. transacción"';
                }
                field("Line No."; "Line No.")
                {
                    Caption = 'Line No.', comment = 'ESP="No. linea"';
                }
                field("Store No."; "Store No.")
                {
                    Caption = 'Store No.', comment = 'ESP="No. tienda"';
                }
                field("POS Terminal No."; "POS Terminal No.")
                {
                    Caption = 'POS Terminal No.', comment = 'ESP="No. terminal"';
                }
                field("Receipt No."; "Receipt No.")
                {
                    Caption = 'Receipt No.', comment = 'ESP="No. Recibo"';
                }
                field("Intentos"; "Intento No.")
                {
                    Caption = 'Attempts', comment = 'ESP="Intentos"';
                }
                field("Staff ID"; "Staff ID")
                {
                    Caption = 'Staff', comment = 'ESP="Empleado"';
                }
                field("Numero Telefono"; "Numero Telefono")
                {
                    Caption = 'Phone number', comment = 'ESP="Número teléfono"';
                }
                field("Monto Recarga"; "Monto Recarga")
                {
                    Caption = 'Recharge amount', comment = 'ESP="Monto recarga"';
                }
                field(Operador; Operador)
                {
                    Caption = 'Operadora', comment = 'ESP="Operadora"';
                }
                field(Fecha; Fecha)
                {
                    Caption = 'Date', comment = 'ESP="Fecha"';
                }
                field(Hora; Hora)
                {
                    Caption = 'Time', comment = 'ESP="Hora"';
                }
                field(Observacion; Observacion)
                {
                    Caption = 'Remark', comment = 'ESP="Observación"';
                }
                field("Control ID"; "Control ID")
                {
                    Caption = 'Control', comment = 'ESP="Control"';
                }
            }
        }
    }

    actions
    {
    }
}

