report 50018 "FSN Reception Direct"
{
    DefaultLayout = RDLC;
    RDLCLayout = './src/Report/Layout/fsnreceptiondirect.rdl';
    ApplicationArea = Warehouse;
    Caption = 'Recepción directa';
    UsageCategory = Documents;

    dataset
    {
        dataitem("Warehouse Receipt Header"; "Warehouse Receipt Header")
        {
            DataItemTableView = SORTING("No.");
            RequestFilterFields = "No.";
            column(No_TransRcptHdr; "No.")
            {
            }
            dataitem(CopyLoop; Integer)
            {
                DataItemTableView = SORTING(Number);
                dataitem(PageLoop; Integer)
                {
                    DataItemTableView = SORTING(Number) WHERE(Number = CONST(1));
                    column(CopyText; StrSubstNo(CopyCaptionLbl, CopyText))
                    {
                    }
                    column(TransferToAddr1; TransferToAddr[1])
                    {
                    }
                    column(TransferToAddr2; TransferToAddr[2])
                    {
                    }
                    column(TransferToAddr3; TransferToAddr[3])
                    {
                    }
                    column(TransferToAddr4; TransferToAddr[4])
                    {
                    }
                    column(TransferToAddr5; TransferToAddr[5])
                    {
                    }
                    column(TransferToAddr6; TransferToAddr[6])
                    {
                    }
                    column(InTransitCode_TransRcptHdr; "Warehouse Receipt Header"."Vendor Shipment No.")
                    {
                        IncludeCaption = true;
                    }
                    column(PostingDate_TransRcptHdr; Format(Today, 0, 4))
                    {
                    }
                    column(No2_TransRcptHdr; "Warehouse Receipt Header"."No.")
                    {
                    }
                    column(TransferToAddr7; TransferToAddr[7])
                    {
                    }
                    column(TransferToAddr8; TransferToAddr[8])
                    {
                    }
                    column(RcptDate_TransRcptHdr; FechaEnvio)
                    {
                    }
                    column(TransferFromAddr8; TransferFromAddr[8])
                    {
                    }
                    column(TransferFromAddr7; TransferFromAddr[7])
                    {
                    }
                    column(TransferFromAddr6; TransferFromAddr[6])
                    {
                    }
                    column(TransferFromAddr5; TransferFromAddr[5])
                    {
                    }
                    column(TransferFromAddr4; TransferFromAddr[4])
                    {
                    }
                    column(TransferFromAddr3; TransferFromAddr[3])
                    {
                    }
                    column(TransferFromAddr2; TransferFromAddr[2])
                    {
                    }
                    column(TransferFromAddr1; TransferFromAddr[1])
                    {
                    }
                    column(PageCaption; StrSubstNo(PageCaptionLbl, ''))
                    {
                    }
                    column(OutputNo; OutputNo)
                    {
                    }
                    column(TransRcptHdrNo2Caption; RemisionNoCaptionLbl)
                    {
                    }
                    dataitem(DimensionLoop1; Integer)
                    {
                        DataItemTableView = SORTING(Number) WHERE(Number = CONST(1));
                        column(DimText; '')
                        {
                        }
                        column(DimensionLoop1Number; 0)
                        {
                        }
                        column(HdrDimCaption; HdrDimCaptionLbl)
                        {
                        }

                        trigger OnPreDataItem()
                        begin
                            if not ShowInternalInfo then
                                CurrReport.Break();
                        end;
                    }
                    dataitem("PITS_WMScd2suc"; "PITS_WMScd2suc")
                    {
                        DataItemLinkReference = "Warehouse Receipt Header";
                        DataItemLink = "FSN Warehouse Receipt No." = FIELD("No.");
                        DataItemTableView = SORTING("FSN Warehouse Receipt No.", "Line No.");
                        column(ShowInternalInfo; ShowInternalInfo)
                        {
                        }
                        column(ItemNo_TransRcpLine; "Item No.")
                        {
                            IncludeCaption = true;
                        }
                        column(Desc_TransRcpLine; Description)
                        {
                            IncludeCaption = true;
                        }
                        column(Qty_TransRcpLine; Quantity)
                        {
                            IncludeCaption = true;
                        }
                        column(UOM_TransRcpLine; "Unit of Measure")
                        {
                            IncludeCaption = true;
                        }
                        column(LineNo_TransRcpLine; "Line No.")
                        {
                        }
                        dataitem(DimensionLoop2; Integer)
                        {
                            DataItemTableView = SORTING(Number) WHERE(Number = CONST(1));
                            column(DimText2; '')
                            {
                            }
                            column(DimensionLoop2Number; 0)
                            {
                            }
                            column(LineDimCaption; LineDimCaptionLbl)
                            {
                            }

                            trigger OnPreDataItem()
                            begin
                                if not ShowInternalInfo then
                                    CurrReport.Break();
                            end;
                        }

                        trigger OnPreDataItem()
                        begin
                            SetFilter("Item No.", '<>%1', '');
                        end;
                    }
                }

                trigger OnAfterGetRecord()
                begin
                    if Number > 1 then begin
                        CopyText := CopyTextLbl;
                        OutputNo += 1;
                    end;
                end;

                trigger OnPreDataItem()
                begin
                    NoOfLoops := 1 + Abs(NoOfCopies);
                    CopyText := '';
                    SetRange(Number, 1, NoOfLoops);
                    OutputNo := 1;
                end;
            }

            trigger OnAfterGetRecord()
            var
                PITSLine: Record PITS_WMScd2suc;
                LocationRec: Record Location;
            begin
                Clear(TransferFromAddr);
                Clear(TransferToAddr);
                FechaEnvio := '';

                // Izquierda (Sucursal): calculado por ubicación del WR
                if LocationRec.Get("Location Code") then begin
                    TransferFromAddr[1] := LocationRec.Name;
                    TransferFromAddr[2] := LocationRec.Address;
                    TransferFromAddr[4] := 'EL SALVADOR';
                    TransferFromAddr[5] := LocationRec."Country/Region Code";
                end;

                // Derecha (CD): fijo
                TransferToAddr[1] := CDRightLine1Lbl;
                TransferToAddr[2] := CDRightLine2Lbl;
                TransferToAddr[3] := CDRightLine3Lbl;
                TransferToAddr[4] := CDRightLine4Lbl;
                TransferToAddr[5] := CDRightLine5Lbl;
                TransferToAddr[6] := CDRightLine6Lbl;

                PITSLine.SetRange("FSN Warehouse Receipt No.", "No.");
                if PITSLine.FindFirst() then
                    FechaEnvio := Format(PITSLine."Starting Date", 0, 4);
            end;
        }
    }

    requestpage
    {
        SaveValues = true;

        layout
        {
            area(content)
            {
                group(Options)
                {
                    Caption = 'Options';
                    field(NoOfCopies; NoOfCopies)
                    {
                        ApplicationArea = Warehouse;
                        Caption = 'No. of Copies';
                    }
                    field(ShowInternalInfo; ShowInternalInfo)
                    {
                        ApplicationArea = Warehouse;
                        Caption = 'Show Internal Information';
                    }
                }
            }
        }
    }

    labels
    {
        PostingDateCaption = 'Fecha registro';
    }

    var
        NoOfCopies: Integer;
        NoOfLoops: Integer;
        CopyText: Text[30];
        ShowInternalInfo: Boolean;
        OutputNo: Integer;
        FechaEnvio: Text[50];
        TransferFromAddr: array[8] of Text[100];
        TransferToAddr: array[8] of Text[100];
        CopyTextLbl: Label 'COPIA';
        CopyCaptionLbl: Label 'Recepción directa %1';
        PageCaptionLbl: Label 'Pág.';
        RemisionNoCaptionLbl: Label 'N° remisión';
        HdrDimCaptionLbl: Label 'Header Dimensions';
        LineDimCaptionLbl: Label 'Line Dimensions';
        CDRightLine1Lbl: Label 'Centro de Distribucion';
        CDRightLine2Lbl: Label 'Km. 10, Carretera al Puerto de La Libertad';
        CDRightLine3Lbl: Label 'La Libertad, 501';
        CDRightLine4Lbl: Label 'Antiguo Cuscatlán';
        CDRightLine5Lbl: Label 'EL SALVADOR';
        CDRightLine6Lbl: Label '';
}

