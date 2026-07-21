page 50094 "FSN Roll Call Center"
{
    PageType = RoleCenter;
    Caption = 'FSN Delivery order list';
    actions
    {
        area(Sections)
        {
            group("Group")
            {
                Caption = 'Area de Tareas Call Center';
                action("Items")
                {
                    ApplicationArea = All;
                    Caption = 'Retail Items', comment = 'ESP="Items"';
                    RunObject = Page "LSC Retail Item List";
                }

                action("Customer List")
                {
                    ApplicationArea = All;
                    Caption = 'Customer List', comment = 'Customers"';
                    RunObject = Page "Customer List";
                }

                action("LSC Staff List")
                {
                    ApplicationArea = All;
                    Caption = 'LSC Staff List', comment = 'ESP="Lista Empleados"';
                    RunObject = Page "LSC Staff List";
                }

                action("LSC Delivery Streets")
                {
                    ApplicationArea = All;
                    Caption = 'LSC Delivery Streets', comment = 'ESP="Calles Reparto"';
                    RunObject = Page "LSC Delivery Streets";
                }

                action("LSC Retail Calendar List")
                {
                    ApplicationArea = All;
                    Caption = 'LSC Retail Calendar List', comment = 'ESP="Calendarios Con Min."';
                    RunObject = Page "LSC Retail Calendar List";
                }

                action("LSC PosCard Entry List")
                {
                    ApplicationArea = All;
                    Caption = 'LSC PosCard Entry', comment = 'ESP="Movs. Tarjeta"';
                    RunObject = Page "LSC POS Card Entries";
                }
                action("LSC Transaction Register")
                {
                    ApplicationArea = All;
                    Caption = 'LSC Transaction Register', comment = 'ESP="Registro Transacc."';
                    RunObject = Page "LSC Transaction Register";
                }

                action("LSC Cmsn Salesperson Group")
                {
                    ApplicationArea = All;
                    Caption = 'LSC Cmsn Salesperson Group', comment = 'ESP="Grupo Vendedores"';
                    RunObject = Page "LSC Cmsn Salesperson Group";
                }

                action("FSN Commutator")
                {
                    ApplicationArea = All;
                    Caption = 'FSN Commutator', comment = 'ESP="FSN Commutator"';
                    RunObject = Page "FSN Commutator";
                }

                action("Liquidar DAF")
                {
                    ApplicationArea = All;
                    Caption = 'Liquidar DAF', comment = 'Liquidar DAF"';
                    RunObject = page "FSN Liquidar DAF";

                }
                action("Pedidos pegados")
                {
                    ApplicationArea = All;
                    Caption = 'Pedido pegado', Comment = 'Pedido pegado';
                    RunObject = page "FSN Delivery Order List";
                }
            }
        }

    }
}