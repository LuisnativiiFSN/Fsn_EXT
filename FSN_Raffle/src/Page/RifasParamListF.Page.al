page 50075 "FSN RifasParam ListF"
{
    Caption = 'Raffle Parameters';
    PageType = List;
    SourceTable = "FSN RifasParam";
    ApplicationArea = all;
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("No Rifa"; "No Rifa")
                {
                }
                field("Store No"; "Store No")
                {
                }
                field(Fecha; Fecha)
                {
                }
                field(FechaFin; FechaFin)
                {
                }
                field(PremiosTotales; PremiosTotales)
                {
                }
                field(PremiosOtorgados; PremiosOtorgados)
                {
                    Editable = false;
                }
            }
        }
    }

    actions
    {
    }
}

