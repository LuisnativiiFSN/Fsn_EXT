page 50072 "FSN RifasDetalle List"
{
    Caption = 'Raffle Details';
    PageType = List;
    SourceTable = "FSN RifasDetalle";
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
                field(Tipo; Tipo)
                {
                }
                field("Line No"; "Line No")
                {
                }
                field(CodSec; CodSec)
                {

                    trigger OnValidate()
                    var
                        xItem: Record "Item";
                        xGrupos: Record "LSC Item Special Groups";
                        xAtt: Record "LSC Attribute Option Value";
                    begin
                        CASE Rec.Tipo OF
                            Rec.Tipo::Articulos:
                                BEGIN
                                    CLEAR(xItem);
                                    IF xItem.GET(Rec.CodSec) THEN
                                        Rec.Descripcion := xItem.Description;
                                END;
                            Rec.Tipo::"Grupos Especiales":
                                BEGIN
                                    CLEAR(xGrupos);
                                    IF xGrupos.GET(Rec.CodSec) THEN
                                        Rec.Descripcion := xGrupos.Description;
                                END;
                        END;
                    end;
                }
                field(Descripcion; Descripcion)
                {
                }
                field(CantMin; CantMin)
                {
                }
                field(ValorMin; ValorMin)
                {
                }
            }
        }
    }

    actions
    {
    }

    trigger OnNewRecord(BelowxRec: Boolean)
    var
        xNoRifa: Code[30];
        xRifa: Record "FSN Rifas";
    begin
        // Recuperar filtro de la tabla
        xNoRifa := '';
        xNoRifa := GETFILTER("No Rifa");

        // Buscar la Rifa
        IF xNoRifa <> '' THEN BEGIN
            IF xRifa.GET(xNoRifa) THEN BEGIN
                Rec."No Rifa" := xRifa.NoRifa;
                Rec.Tipo := xRifa.Tipo;
                Rec.CodAtributo := xRifa.CodAtributo;
                Rec."Line No" := GetNextSeq();
            END ELSE BEGIN
                ERROR('Error en filtro de página...');
            END;
        END /* ELSE BEGIN
            ERROR('Filtre la vista por la Rifa a la que desea agregar registro...');
        END; */
    end;

    var
        pNoRifa: Code[30];
        pTipo: Option Articulos,Marcas,Atributos,"Grupos Especiales";
        pCodAtributo: Code[20];

    procedure SetNoRifa(xNoRifa: Code[30])
    begin
        pNoRifa := xNoRifa;
    end;

    procedure SetTipo(xTipo: Option Articulos,Marcas,Atributos,"Grupos Especiales")
    begin
        pTipo := xTipo;
    end;

    procedure SetCodAtributo(xCodAtributo: Code[20])
    begin
        pCodAtributo := xCodAtributo;
    end;

    procedure GetNextSeq(): Decimal
    var
        xDet: Record "FSN RifasDetalle";
        xLast: Integer;
    begin
        xLast := 0;
        CLEAR(xDet);
        xDet.SETRANGE("No Rifa", Rec."No Rifa");
        IF xDet.FIND('-') THEN
            REPEAT
                IF xDet."Line No" > xLast THEN
                    xLast := xDet."Line No";
            UNTIL xDet.NEXT <= 0;

        EXIT(xLast + 1000);
    end;
}

