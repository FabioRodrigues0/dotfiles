module ${package} {
    requires fabiorodrigues.bricks;
    requires javafx.controls;
    requires javafx.graphics;

    opens ${package} to javafx.graphics;
    exports ${package};
}
