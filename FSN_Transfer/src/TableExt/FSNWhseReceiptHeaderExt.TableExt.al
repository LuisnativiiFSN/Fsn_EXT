tableextension 50070 "FSN Whse Receipt Header Ext" extends "Warehouse Receipt Header"
{
    //JHERNANDEZ 1.0.0.14            - C/AL to AL

    Caption = 'Recep. Almacen Ext';

    fields
    {
        field(60001; "Status"; Option)
        {
            Caption = 'Status';
            OptionCaption = 'Ninguno,AplicandoAutomatico...';
            OptionMembers = Ninguno,AplicandoAutomatico;
        }
        field(60002; "FSN Proc Status"; Option)
        {
            Caption = 'Estado Proceso';
            OptionMembers = PorProcesar,Procesando,Error;
            OptionCaption = 'Por procesar,Procesando,Error';
            InitValue = PorProcesar;
        }
        field(60003; "FSN Proc Error"; Text[250])
        {
            Caption = 'Error Proceso';
        }
    }
}