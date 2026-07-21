table 50031 "FSN Purchase Excepcion"
{
    DataClassification = ToBeClassified;
    Permissions = TableData "FSN Purchase Excepcion" = rimd;
    fields
    {
        field(1; "Item No."; Code[20])
        {
            TableRelation = Item;
            ValidateTableRelation = false;
        }
        field(2; "Purch. Unit of Measure"; Code[10])
        {
            TableRelation = "Unit of Measure";
            ValidateTableRelation = false;
        }
        field(3; "Location Code"; Code[10])
        {
            TableRelation = Location;
            ValidateTableRelation = false;
        }

        field(4; "LSC Attrib 1 Code"; Text[30])
        {
            Caption = 'Laboratory';
            TableRelation = "LSC Attribute Option Value"."Option Value" where("Attribute Code" = filter(= 'LABORATORIO'));
            ValidateTableRelation = false;

        }

        field(5; "Use Priority Attrib 1 Code"; Boolean)
        {
            Caption = 'Use Priority Laboratory';
        }

        field(6; "Active From Date"; Date)
        {
            Caption = 'Active From Date';
        }
        field(7; "Type Control"; Option)
        {
            Caption = 'Type Control';
            OptionCaption = 'Sin Establecer,Limitado dentro del Rago Minimo,Asignacion en cantidad directamente,Tiempo Reaprov. manual Minimo y Maximo (Dias),Aproximado a multiplo mas cercano,Aproximado a multiplo mayor,Apx. a multiplo con tiempo reorden limitado (Dias),Tiempo reorden limitado (Dias),No reducir niveles de stock solo aumentar,No reducir stock niveles Punto reorden limitado,No incluir en analisis Reaprov.,Mix Laboratorio Tiempo reorden+excepcion prod/lab.,Obsequio(Venta.Venta+Obsequio.MaxVeces[multiplo],,DisminucionRiesgo,ABC';
            OptionMembers = SinEstablecer,LimitadodentrodelRagoMinimo,Asignacionencantidaddirectamente,TiempoReaprovmanualMinimoyMaximoDias,Aproximadoamultiplomascercano,Aproximadoamultiplomayor,ApxamultiplocontiemporeordenlimitadoDias,TiemporeordenlimitadoDias,Noreducirnivelesdestocksoloaumentar,NoreducirstocknivelesPuntoreordenlimitado,NoincluirenanalisisReaprov,MixLaboratorioTiemporeordenexcepcionprodlab,ObsequioVentaVentaObsequioMaxVecesmultiplo,,DisminucionRiesgo,ABC;
        }

        field(8; "Range Lim. Point Reorder"; Decimal)
        {
            Caption = 'Range Lim. Point Reorder';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }

        field(9; "Range Lim. Max Stock"; Decimal)
        {
            Caption = 'Range Lim. Max Stock';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(10; "Manual Reorder Point"; Decimal)
        {
            Caption = 'Manual Reorder Point';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }
        field(11; "Max Manual Stock"; Decimal)
        {
            Caption = 'Max Manual Stock';
            DecimalPlaces = 0 : 5;
            MinValue = 0;
        }

        field(12; "Reorder time Min. Man (Days)"; Decimal)
        {
            Caption = 'Reorder time Min. Man (Days)';
            DecimalPlaces = 0 : 5;
        }

        field(13; "Reorder time Max. Man (Days)"; Decimal)
        {
            Caption = 'Reorder time Max. Man (Days)';
            DecimalPlaces = 0 : 5;
        }

        field(14; "Time Reorder Lim. (Days)"; Decimal)
        {
            Caption = 'Time Reorder Lim. (Days)';
            DecimalPlaces = 0 : 5;
        }
        field(15; "Definition Exception"; Text[50])
        {
            Caption = 'Definition Exception';

        }
        field(16; "Type Exception"; Option)
        {
            Caption = 'Type Exception';
            OptionCaption = 'By Item,By Laboratory';
            OptionMembers = ByItem,ByLaboratory;
        }
        field(17; "Multiple"; Decimal)
        {
            Caption = 'Multiple';
            DecimalPlaces = 0 : 5;
        }
        field(18; "Active To Date"; Date)
        {
            Caption = 'Active To Date';
        }


    }

    keys
    {
        key(Key1; "Item No.", "Location Code", "LSC Attrib 1 Code")
        {
            Clustered = true;
        }

    }

    var
        Item: Record Item;

    trigger OnInsert()
    begin

    end;

    trigger OnModify()
    begin

    end;

    trigger OnDelete()
    begin

    end;

    trigger OnRename()
    begin

    end;

}