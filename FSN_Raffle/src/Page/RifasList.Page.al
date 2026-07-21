page 50098 "FSN Rifas List"
{
    Caption = 'Raffles';
    PageType = List;
    SourceTable = "FSN Rifas";
    ApplicationArea = all;
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(NoRifa; NoRifa)
                {
                }
                field(Descripcion; Descripcion)
                {
                }
                field(Tipo; Tipo)
                {
                }
                field(TipoDisparador; TipoDisparador)
                {
                }
                field(NoSerie; NoSerie)
                {
                }
                field("Print Extra"; "Print Extra")
                {
                }
                field("Print Extra Perdedor"; "Print Extra Perdedor")
                {
                }
                field(CodAtributo; CodAtributo)
                {
                }
                field(FechaInicio; FechaInicio)
                {
                }
                field(FechaFin; FechaFin)
                {
                }
                field(HoraInicio; HoraInicio)
                {
                }
                field(HoraFin; HoraFin)
                {
                }
                field(VIP; VIP)
                {
                }
                field(CondMinimas; CondMinimas)
                {
                }
                field(ValorMinimo; ValorMinimo)
                {
                }
                field(ImprimirTicketPierde; ImprimirTicketPierde)
                {
                }
                field(Linea1Gana; Linea1Gana)
                {
                }
                field(Linea2Gana; Linea2Gana)
                {
                }
                field(Linea3Gana; Linea3Gana)
                {
                }
                field(Linea1Pierde; Linea1Pierde)
                {
                }
                field(Linea2Pierde; Linea2Pierde)
                {
                }
                field(Linea3Pierde; Linea3Pierde)
                {
                }
                field(ImprimirCond; ImprimirCond)
                {
                }
                field(Linea1Cond; Linea1Cond)
                {
                }
                field(Linea2Cond; Linea2Cond)
                {
                }
                field(Linea3Cond; Linea3Cond)
                {
                }
                field(Linea4Cond; Linea4Cond)
                {
                }
                field(Linea5Cond; Linea5Cond)
                {
                }
                field(Linea6Cond; Linea6Cond)
                {
                }
                field(Linea7Cond; Linea7Cond)
                {
                }
                field(Linea8Cond; Linea8Cond)
                {
                }
                field(Linea9Cond; Linea9Cond)
                {
                }
                field(Linea10Cond; Linea10Cond)
                {
                }
                field(Imagen; Imagen)
                {
                }
                field(OffValidate; OffValidate)
                {
                    Caption = 'Off Validate';
                }
            }
        }
    }

    actions
    {
        area(creation)
        {
            action(DefinirDetalle)
            {
                Caption = 'Define Filters';
                Image = "Filter";
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                RunObject = Page "FSN RifasDetalle List";
                RunPageLink = "No Rifa" = FIELD(NoRifa);
                RunPageView = SORTING("No Rifa", "Line No")
                              ORDER(Ascending);

                trigger OnAction()
                var
                    pDetail: Page "FSN RifasDetalle List";
                begin
                end;
            }
            /*separator()
            {
            }*/
            action("Tiendas Por Rifa")
            {
                Caption = 'Raffle per Store';
                Image = Statistics;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                RunObject = Page "FSN RifasTiendasF";
            }
            action("Parametros Diarios")
            {
                Caption = 'Dayly Parameters';
                Image = AddWatch;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                RunObject = Page "FSN RifasParam ListF";
            }
            action(Historial)
            {
                Caption = 'Raffles Log';
                Image = History;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                RunObject = Page "FSN RifasHistorial ListF";
            }
            action("Grupos Excluidos")
            {
                Caption = 'Excluded Cust. Disc. Groups';
                Image = ExchProdBOMItem;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                RunObject = Page "FSN Rifas Excluded GroupsF";
                RunPageLink = RifaNo = FIELD(NoRifa);
            }
        }
    }
}

