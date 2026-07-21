page 50117 "FSN Purchase Excepcion Card"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "FSN Purchase Excepcion";


    layout
    {
        area(Content)
        {
            group(Exception)
            {

                field("Type Exception"; Rec."Type Exception")
                {
                    ApplicationArea = All;
                    Caption = 'Type Exception';
                    trigger OnValidate()
                    begin
                        InitializeVariables();
                    end;
                }
                field("Type Control"; Rec."Type Control")
                {
                    ApplicationArea = All;
                    Caption = 'Type Control';
                    trigger OnValidate()
                    begin

                        InitializeVariables();
                    end;
                }

            }

            group(General)
            {
                group(ItemNo)
                {
                    Visible = viItemNo;
                    ShowCaption = false;
                    field("Item No."; Rec."Item No.")
                    {
                        ApplicationArea = All;
                        ToolTip = '';
                        ShowMandatory = true;
                        trigger OnValidate()
                        var
                            Item: Record Item;
                        begin
                            item.Reset();
                            item.SetRange("No.", Rec."Item No.");
                            if item.FindFirst() then begin
                                descripcion := item.Description;
                                PurchUnitMeasure := item."Purch. Unit of Measure";
                            end;

                        end;
                    }

                    field(Description; descripcion)
                    {
                        Caption = 'Description';
                        Editable = false;
                    }
                    field("Purch. Unit of Measure"; PurchUnitMeasure)
                    {
                        Editable = false;
                        Caption = 'Purch. Unit of Measure';
                    }

                }
                group(Laboratory)
                {
                    Visible = viLaboratory;
                    ShowCaption = false;

                    field("LSC Attrib 1 Code"; Rec."LSC Attrib 1 Code")
                    {
                        ApplicationArea = All;
                        Caption = 'Laboratory';
                        ShowMandatory = true;

                    }
                    field("Use Priority Attrib 1 Code"; Rec."Use Priority Attrib 1 Code")
                    {
                        ApplicationArea = All;
                        Caption = 'Use Priority Laboratory';
                    }
                }


                field("Location Code"; Rec."Location Code")
                {
                    ApplicationArea = All;
                    ToolTip = '';
                    ShowMandatory = true;

                }

                field("Active From Date"; Rec."Active From Date")
                {
                    ApplicationArea = All;
                    Caption = 'Active From Date';
                    ShowMandatory = true;
                }

                field("Active To Date"; Rec."Active To Date")
                {
                    ApplicationArea = All;
                    Caption = 'Active To Date';
                }

                group(MultipleGroup)
                {
                    Visible = viMultiple;
                    ShowCaption = false;
                    field(Multiple; Rec.Multiple)
                    {
                        ApplicationArea = All;
                        Caption = 'Multiply';
                    }
                }
                group(RangeLimPoint)
                {
                    Visible = viRangeLimPoint;
                    ShowCaption = false;
                    field("Range Lim. Point Reorder"; Rec."Range Lim. Point Reorder")
                    {
                        ApplicationArea = All;
                        Caption = 'Range Lim. Point Reorder';
                    }
                }
                group(RangeLimMaxStock)
                {
                    Visible = viRangeLimMaxStock;
                    ShowCaption = false;
                    field("Range Lim. Max Stock"; Rec."Range Lim. Max Stock")
                    {
                        ApplicationArea = All;
                        Caption = 'Range Lim. Max Stock';
                    }
                }
                group(ManReorderPoint)
                {
                    Visible = viManReorderPoint;
                    ShowCaption = false;
                    field("Manual Reorder Point"; Rec."Manual Reorder Point")
                    {
                        ApplicationArea = All;
                        Caption = 'Manual Reorder Point';
                    }
                }
                group(MaxManStock)
                {
                    Visible = viMaxManStock;
                    ShowCaption = false;
                    field("Max Manual Stock"; Rec."Max Manual Stock")
                    {
                        ApplicationArea = All;
                        Caption = 'Maximum Manual Stock';
                    }
                }
                group(ReorderTimeMinMan)
                {
                    Visible = viReorderTimeMinMan;
                    ShowCaption = false;
                    field("Reorder time Min. Man (Days)"; Rec."Reorder time Min. Man (Days)")
                    {
                        ApplicationArea = All;
                        Caption = 'Reorder time Min. Man (Days)';
                    }
                }
                group(ReorderTimeMaxMan)
                {
                    Visible = viReorderTimeMaxMan;
                    ShowCaption = false;
                    field("Reorder time Max. Man (Days)"; Rec."Reorder time Max. Man (Days)")
                    {
                        ApplicationArea = All;
                        Caption = 'Reorder time Max. Man (Days)';
                    }
                }
                group(TimeReorderLim)
                {
                    Visible = viTimeReoderLim;
                    ShowCaption = false;
                    field("Time Reorder Lim. (Days)"; Rec."Time Reorder Lim. (Days)")
                    {
                        ApplicationArea = All;
                        Caption = 'Time Reorder Lim. (Days)';

                    }
                }
                group(Definicion)
                {
                    Visible = viDeficionException;
                    ShowCaption = false;
                    field("Definition Exception"; Rec."Definition Exception")
                    {
                        ApplicationArea = All;
                        Caption = 'Definition Exception';
                    }
                }

            }
        }
    }



    var
        [InDataSet]
        viDeficionException, viMultiple, viTimeReoderLim, viLaboratory, viItemNo, viReorderTimeMaxMan, viReorderTimeMinMan, viMaxManStock, viManReorderPoint, viRangeLimMaxStock, viRangeLimPoint : Boolean;
        descripcion: code[100];
        PurchUnitMeasure: code[10];

        Tex001: Label 'This action is not available for Laboratory exception type';


    trigger OnOpenPage()
    var
        myInt: Integer;
    begin
        //viDeficionException := true;
        InitializeVariables();
    end;

    local procedure InitializeVariables()
    begin


        case Rec."Type Exception" of
            Rec."Type Exception"::ByItem:
                begin
                    SetGroupVisible(true, false);
                    case Rec."Type Control" of
                        Rec."Type Control"::SinEstablecer:
                            SetFieldsVisible(false, false, false, false, false, false, false, false, true);
                        Rec."Type Control"::LimitadodentrodelRagoMinimo:
                            SetFieldsVisible(false, true, true, false, false, false, false, false, true);
                        Rec."Type Control"::Asignacionencantidaddirectamente:
                            SetFieldsVisible(false, false, false, true, true, false, false, false, true);
                        Rec."Type Control"::TiempoReaprovmanualMinimoyMaximoDias:
                            SetFieldsVisible(false, false, false, false, false, true, true, false, true);
                        Rec."Type Control"::Aproximadoamultiplomascercano:
                            SetFieldsVisible(true, false, false, false, false, false, false, false, true);
                        Rec."Type Control"::Aproximadoamultiplomayor:
                            SetFieldsVisible(true, false, false, false, false, false, false, false, true);
                        Rec."Type Control"::ApxamultiplocontiemporeordenlimitadoDias:
                            SetFieldsVisible(true, false, false, false, false, true, true, false, true);
                        Rec."Type Control"::TiemporeordenlimitadoDias:
                            SetFieldsVisible(false, false, false, false, false, false, false, true, true);
                        Rec."Type Control"::Noreducirnivelesdestocksoloaumentar:
                            SetFieldsVisible(false, false, false, false, false, false, false, false, true);
                        Rec."Type Control"::NoreducirstocknivelesPuntoreordenlimitado:
                            SetFieldsVisible(false, true, false, false, false, false, false, false, true);
                        Rec."Type Control"::NoincluirenanalisisReaprov:
                            SetFieldsVisible(false, false, false, false, false, false, false, false, true);
                        Rec."Type Control"::MixLaboratorioTiemporeordenexcepcionprodlab:
                            SetFieldsVisible(false, false, false, false, false, false, false, true, true);
                        Rec."Type Control"::ObsequioVentaVentaObsequioMaxVecesmultiplo:
                            SetFieldsVisible(true, true, true, false, false, false, false, false, true);
                    end;
                end;
            Rec."Type Exception"::ByLaboratory:
                begin
                    SetGroupVisible(false, true);
                    case Rec."Type Control" of
                        Rec."Type Control"::SinEstablecer:
                            SetFieldsVisible(false, false, false, false, false, false, false, false, true);
                        Rec."Type Control"::LimitadodentrodelRagoMinimo:
                            begin
                                SetGroupVisible(false, false);
                                SetFieldsVisible(false, false, false, false, false, false, false, false, false);
                                Message(Tex001);
                            end;
                        Rec."Type Control"::Asignacionencantidaddirectamente:
                            begin
                                SetGroupVisible(false, false);
                                SetFieldsVisible(false, false, false, false, false, false, false, false, false);
                                Message(Tex001);
                            end;
                        Rec."Type Control"::TiempoReaprovmanualMinimoyMaximoDias:
                            begin
                                SetGroupVisible(false, false);
                                SetFieldsVisible(false, false, false, false, false, false, false, false, false);
                                Message(Tex001);
                            end;
                        Rec."Type Control"::Aproximadoamultiplomascercano:
                            begin
                                SetGroupVisible(false, false);
                                SetFieldsVisible(false, false, false, false, false, false, false, false, false);
                                Message(Tex001);
                            end;
                        Rec."Type Control"::Aproximadoamultiplomayor:
                            begin
                                SetGroupVisible(false, false);
                                SetFieldsVisible(false, false, false, false, false, false, false, false, false);
                                Message(Tex001);
                            end;
                        Rec."Type Control"::ApxamultiplocontiemporeordenlimitadoDias:
                            begin
                                SetGroupVisible(false, false);
                                SetFieldsVisible(false, false, false, false, false, false, false, false, false);
                                Message(Tex001);
                            end;
                        Rec."Type Control"::TiemporeordenlimitadoDias:
                            SetFieldsVisible(false, false, false, false, false, false, false, true, true);
                        Rec."Type Control"::Noreducirnivelesdestocksoloaumentar:
                            SetFieldsVisible(false, false, false, false, false, false, false, false, true);
                        Rec."Type Control"::NoreducirstocknivelesPuntoreordenlimitado:
                            SetFieldsVisible(false, true, false, false, false, false, false, false, true);
                        Rec."Type Control"::NoincluirenanalisisReaprov:
                            SetFieldsVisible(false, false, false, false, false, false, false, false, true);
                        Rec."Type Control"::MixLaboratorioTiemporeordenexcepcionprodlab:
                            SetFieldsVisible(false, false, false, false, false, false, false, true, true);
                        Rec."Type Control"::ObsequioVentaVentaObsequioMaxVecesmultiplo:
                            begin
                                SetGroupVisible(false, false);
                                SetFieldsVisible(false, false, false, false, false, false, false, false, false);
                                Message(Tex001);
                            end;
                        Rec."Type Control"::ABC:
                            begin
                                SetFieldsVisible(false, false, false, false, false, true, true, false, true);
                            end;
                    end;
                end;

        end;
    end;

    local procedure SetFieldsVisible(pMultipleGroup: Boolean; pRangeLimPoint: Boolean; pRangeLimMaxStock: Boolean; pManReorderPoint: Boolean;
        pMaxManStock: Boolean; pReorderTimeMinMan: Boolean; pReorderTimeMaxMan: Boolean; pTimeReorderLim: Boolean; pDefinicionExcepcion: Boolean)
    begin
        viMultiple := pMultipleGroup;
        viRangeLimPoint := pRangeLimPoint;
        viRangeLimMaxStock := pRangeLimMaxStock;
        viManReorderPoint := pManReorderPoint;
        viMaxManStock := pMaxManStock;
        viReorderTimeMinMan := pReorderTimeMinMan;
        viReorderTimeMaxMan := pReorderTimeMaxMan;
        viTimeReoderLim := pTimeReorderLim;
        viDeficionException := pDefinicionExcepcion;

    end;

    local procedure SetGroupVisible(pviItemNo: Boolean; pviLaboratory: Boolean)
    begin
        viItemNo := pviItemNo;
        viLaboratory := pviLaboratory;
        if pviItemNo then begin
            Rec."LSC Attrib 1 Code" := '';
        end;
        if pviLaboratory then begin
            Rec."Item No." := '';
        end;
    end;





}