page 50108 "FSN Reservado"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "FSN Reservacion";
    Caption = 'FSN Reservacion';


    layout
    {
        area(content)
        {
            repeater(General)
            {
                field(Item; Item)
                {
                }
                field(Tienda; Tienda)
                {
                }
                field(Description; Description)
                {
                    Editable = false;
                }
                field("Cant. a reservar"; "Cant. a reservar")
                {
                }
                field(Reservar; Reservar)
                {
                }
                field(Comentario; Comentario)
                {
                }
                field("Fecha Revervado"; "Fecha Revervado")
                {
                    Enabled = false;
                }
                field("Fecha Creado"; "Fecha Creado")
                {
                    Editable = false;
                }
                field("Hora Creado"; "Hora Creado")
                {
                    Editable = false;
                }
                field("Usuario Creacion"; "Usuario Creacion")
                {
                    Editable = false;
                }
                field("Ultimo Usuario"; "Ultimo Usuario")
                {
                }
            }
        }
    }

    actions
    {
    }
}

