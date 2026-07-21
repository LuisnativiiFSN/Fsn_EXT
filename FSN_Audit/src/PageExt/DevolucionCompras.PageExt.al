pageextension 50168 PageExtension50008 extends "Vendor Lookup"
{
    layout
    {
        addafter(Name)
        {
            // se agrego el campo de search name para que se pueda filtrar la busqueda tanto por alias como por nombre
            // en dev com 
            field("Search Name55174";Rec."Search Name")
            {
                ApplicationArea = All;
            }
        }
    }
}
