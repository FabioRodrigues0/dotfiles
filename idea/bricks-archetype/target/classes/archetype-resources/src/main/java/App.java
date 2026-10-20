package ${package};

import fabiorodrigues.bricks.components.Column;
import fabiorodrigues.bricks.components.Text;
import fabiorodrigues.bricks.core.BricksApplication;
import fabiorodrigues.bricks.core.Component;

public class App extends BricksApplication {

    {
        setTitle("${artifactId}");
    }

    @Override
    public Component root() {
        return new Column()
            .padding(20)
            .gap(12)
            .children(
                new Text("Ola, Bricks!")
            );
    }

    public static void main(String[] args) {
        launch(args);
    }
}
