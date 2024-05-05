# **Health Data Tool**

## **Overview**

This tool converts the XML exported by Apple's iOS Health app to JSON, making it easier to import into your database of choice.

## **Building and Installation**

This tool is written in OCaml and can be built using Dune. To build and install the tool, follow these steps:

1. Install OCaml 5+ and Dune using your package manager or by building from source
2. Clone this repository and navigate to the project directory
3. Run `opam install -y . --deps-only` to install dependencies
4. Run `dune build` to build the tool
5. Run `dune install` to install the tool

## **Requirements**

- OCaml 5+ (required for building and running the tool)
- Dune (required for building and installing the tool)

## **Getting Started**

### **Watch**

The `watch` command monitors a specified folder for the `export.zip` archive exported by the Health app. When a new archive is detected, it is unzipped and the contained `export.xml` file is converted to JSON.

```
health-data-tool watch <folder_path> <output_file_path>
```

### **Convert**

The `convert` command takes an `export.xml` file as input and converts it to JSON.

```
health-data-tool convert <xml_file_path> <output_file_path>
```
