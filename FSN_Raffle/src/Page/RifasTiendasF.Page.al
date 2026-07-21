page 50076 "FSN RifasTiendasF"
{
    Caption = 'Rifas';
    PageType = List;
    SourceTable = "FSN RifasTiendas";
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
                field(Probabilidad; Probabilidad)
                {
                }
                field(ParametrosDiarios; ParametrosDiarios)
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
        area(creation)
        {
        }
    }
}

