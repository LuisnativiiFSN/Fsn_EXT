page 50078 "FSN Recargas Electronicas"
{
    PageType = List;
    Caption = 'Successful recharges', comment = 'ESP="Recargas Exitosas"';
    SourceTable = "FSN Recargas Electronicas";
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
                    Caption = 'Receipt No.', comment = 'ESP="No. recibo"';
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
                field(Estado; Estado)
                {
                    Caption = 'Status', comment = 'ESP="Estado"';
                }
                field(Fecha; Fecha)
                {
                    Caption = 'Date', comment = 'ESP="Fecha"';
                }
                field(Hora; Hora)
                {
                    Caption = 'Time', comment = 'ESP="Hora"';
                }
                field("Transaccion Operador"; "Transaccion Operador")
                {
                    Caption = 'Transaction Operator', comment = 'ESP="Transacción operador"';
                }
                field("Respuesta Servicio"; "Respuesta Servicio")
                {
                    Caption = 'Response Service', comment = 'ESP="Respuesta servicio"';
                }
                field("Monto Debitado"; "Monto Debitado")
                {
                    Caption = 'Amount Debited', comment = 'ESP="Monto debitado"';
                }
                field("Monto Acreditado"; "Monto Acreditado")
                {
                    Caption = 'Amount Credited', comment = 'ESP="Monto acreditado"';
                }
                field("Comision Debitada O"; "Comision Debitada O")
                {
                    Caption = 'Commission Debited O', comment = 'ESP="Comisión debitada O"';
                }
                field("Comision Aplicada O"; "Comision Aplicada O")
                {
                    Caption = 'Applied Commission O', comment = 'ESP="Comisión aplicada O"';
                }
                field("Comision Debitada D"; "Comision Debitada D")
                {
                    Caption = 'Commission Debited D', comment = 'ESP="Comisión debitada D"';
                }
                field("Comision Aplicada D"; "Comision Aplicada D")
                {
                    Caption = 'Applied Commission D', comment = 'ESP="Comisión aplicada D"';
                }
                field("Monto Disponible"; "Monto Disponible")
                {
                    Caption = 'Amount available', comment = 'ESP="Monto disponible"';
                }
            }
        }
    }

    actions
    {
    }
}

