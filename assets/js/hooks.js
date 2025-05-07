import * as d3 from "d3";

let Hooks = {}

Hooks.GraphHook = {
  mounted() {
    console.log("GraphHook mounted!");

    d3.json("/graph.json").then(data => {
      console.log("Loaded graph data:", data);

      const svg = d3.select(this.el.querySelector("svg"));
      const width = +svg.attr("width");
      const height = +svg.attr("height");

      const zoomLayer = svg.append("g");

      svg.call(d3.zoom()
        .scaleExtent([0.1, 5])
        .on("zoom", (event) => {
          zoomLayer.attr("transform", event.transform);
        }));

      const simulation = d3.forceSimulation(data.nodes)
        .force("link", d3.forceLink(data.links).id(d => d.id).distance(50))
        .force("charge", d3.forceManyBody().strength(-100))
        .force("center", d3.forceCenter(width / 2, height / 2));

      const link = zoomLayer.append("g")
        .attr("stroke", "#1e90ff") //
        .attr("stroke-opacity", 0.9)
        .attr("stroke-width", 1.5)
        .selectAll("line")
        .data(data.links)
        .join("line")
        .attr("class", "link");

      const node = zoomLayer.append("g")
        .selectAll("g")
        .data(data.nodes)
        .join("g")
        .attr("class", "node")
        .call(d3.drag()
          .on("start", dragstart)
          .on("drag", dragged)
          .on("end", dragend));

      node.append("circle")
        .attr("r", d => d.type === "InputPort" ? 8 : 20)  // <<< InputPorts are smaller
        .attr("fill", d => {
          console.log("Drawing node:", d);
          if (d.type === "Invocation") return "#1e90ff"; // blue
          if (d.type === "Definition") return "#32cd32"; // green
          if (d.type === "Signal") {
            if (d.state === "1") return "lime";   // active signal
            else if (d.state === "0") return "red"; // inactive signal
            else return "#ffa500"; // unknown signal
          }
          if (d.type === "InputPort") return "#000000"; // black for input ports
          if (d.type === "Literal") return "#ffff00"; // yellow for constants
          return "#aaa"; // fallback color
        });

      node.append("text")
        .attr("dy", 5)
        .attr("text-anchor", "middle")
        .text(d => d.id);

      simulation.on("tick", () => {
        link
          .attr("x1", d => d.source.x)
          .attr("y1", d => d.source.y)
          .attr("x2", d => d.target.x)
          .attr("y2", d => d.target.y);

        node
          .attr("transform", d => `translate(${d.x},${d.y})`);
      });

      function dragstart(event, d) {
        if (!event.active) simulation.alphaTarget(0.3).restart();
        d.fx = d.x; d.fy = d.y;
      }

      function dragged(event, d) {
        d.fx = event.x; d.fy = event.y;
      }

      function dragend(event, d) {
        if (!event.active) simulation.alphaTarget(0);
        d.fx = null; d.fy = null;
      }
    }).catch(error => {
      console.error("Failed to load graph.json:", error);
    });
  }
};

Hooks.ClipboardCopy = {
  mounted() {
    const initialInnerHTML = this.el.innerHTML;
    const { content } = this.el.dataset;

    this.el.addEventListener("click", () => {
      navigator.clipboard.writeText(content);
      this.el.innerHTML = "Copied!";
      setTimeout(() => {
        this.el.innerHTML = initialInnerHTML;
      }, 2000);
    });
  }
}

Hooks.ClipboardPaste = {
  mounted() {
    this.el.addEventListener("click", () => {
      navigator.clipboard.readText().then((text) => {
        this.pushEvent("block-pasted", { pastedText: text });
      }).catch(err => {
        console.error('Failed to read clipboard contents: ', err);
      });
    });
  }
}

export default Hooks;
