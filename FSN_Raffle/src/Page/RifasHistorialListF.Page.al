page 50074 "FSN RifasHistorial ListF"
{
    Caption = 'Raffles Log';
    PageType = List;
    SourceTable = "FSN RifasHistorialF";
    ApplicationArea = all;
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Rifa No"; "Rifa No")
                {
                }
                field("Store No"; "Store No")
                {
                }
                field("Receipt No"; "Receipt No")
                {
                }
                field(Fecha; Fecha)
                {
                }
                field(Ganador; Ganador)
                {
                }
                field(NumGenerado; NumGenerado)
                {
                }
                field(Probabilidad; Probabilidad)
                {
                }
            }
        }
    }

    actions
    {
    }
}

